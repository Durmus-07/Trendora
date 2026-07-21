import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TrendyolSayfasi extends StatefulWidget {
  const TrendyolSayfasi({super.key});

  @override
  State<TrendyolSayfasi> createState() => _TrendyolSayfasiState();
}

class _TrendyolSayfasiState extends State<TrendyolSayfasi> {
  final String apiAdresi = 'http://192.168.1.11:3000/urunler';

  bool yukleniyor = true;
  String? hataMesaji;
  List<dynamic> urunler = [];

  @override
  void initState() {
    super.initState();
    urunleriGetir();
  }

  Future<void> urunleriGetir() async {
    try {
      final cevap = await http.get(Uri.parse(apiAdresi));

      if (cevap.statusCode == 200) {
        setState(() {
          urunler = jsonDecode(cevap.body);
          yukleniyor = false;
          hataMesaji = null;
        });
      } else {
        setState(() {
          yukleniyor = false;
          hataMesaji = 'Sunucu hatası: ${cevap.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        yukleniyor = false;
        hataMesaji = 'Bağlantı kurulamadı.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trendyol Fırsatları'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: urunleriGetir,
        child: _sayfaGovdesi(),
      ),
    );
  }

  Widget _sayfaGovdesi() {
    if (yukleniyor) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (hataMesaji != null) {
      return ListView(
        children: [
          const SizedBox(height: 140),
          const Icon(
            Icons.wifi_off,
            size: 70,
          ),
          const SizedBox(height: 16),
          Text(
            hataMesaji!,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  yukleniyor = true;
                  hataMesaji = null;
                });

                urunleriGetir();
              },
              child: const Text('Tekrar Dene'),
            ),
          ),
        ],
      );
    }

    if (urunler.isEmpty) {
      return const Center(
        child: Text('Henüz ürün bulunamadı.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: urunler.length,
      itemBuilder: (context, index) {
        final urun = urunler[index];

        final String ad = urun['ad']?.toString() ?? 'Ürün';
        final String magaza = urun['magaza']?.toString() ?? 'Mağaza';
        final num fiyat = urun['fiyat'] ?? 0;
        final num eskiFiyat = urun['eskiFiyat'] ?? 0;
        final num indirim = urun['indirimYuzdesi'] ?? 0;
        final num trendPuani = urun['trendPuani'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  magaza,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '$fiyat TL',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$eskiFiyat TL',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text('%$indirim indirim'),
                    ),
                    Chip(
                      label: Text('Trendora puanı: $trendPuani'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}