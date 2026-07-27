import 'package:flutter/material.dart';

import 'core/personalization/interest_catalog.dart';
import 'core/personalization/personalization_service.dart';
import 'core/personalization/personalization_storage.dart';

class IlgiAlanlariSayfasi extends StatefulWidget {
  const IlgiAlanlariSayfasi({super.key, this.service});

  final PersonalizationService? service;

  @override
  State<IlgiAlanlariSayfasi> createState() => _IlgiAlanlariSayfasiState();
}

class _IlgiAlanlariSayfasiState extends State<IlgiAlanlariSayfasi> {
  final Set<String> _selectedInterestIds = {};
  PersonalizationService? _service;
  bool _loading = true;
  bool _saving = false;
  bool _storageAvailable = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final service = widget.service ?? await _createService();
      final preferences = await service.initialize();
      if (!mounted) return;
      setState(() {
        _service = service;
        _selectedInterestIds
          ..clear()
          ..addAll(preferences.interests);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _storageAvailable = false;
      });
    }
  }

  Future<PersonalizationService> _createService() async {
    final storage = await SharedPreferencesPersonalizationStore.create();
    return PersonalizationService(
      repository: PersonalizationLocalRepository(storage),
      identityProvider: PersonalizationIdentityProvider(storage),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final service = _service;
    if (service == null) {
      _showSaveFailure();
      return;
    }

    setState(() => _saving = true);
    try {
      await service.updateInterests(_selectedInterestIds);
      final result = await service.setPersonalizationEnabled(
        _selectedInterestIds.isNotEmpty,
      );
      final saved =
          result.interests.length == _selectedInterestIds.length &&
          result.interests.containsAll(_selectedInterestIds) &&
          result.personalizationEnabled == _selectedInterestIds.isNotEmpty;
      if (!mounted) return;
      if (!saved) {
        _showSaveFailure();
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _showSaveFailure();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSaveFailure() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tercihler şu anda kaydedilemiyor. Uygulamayı kullanmaya devam edebilirsin.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      appBar: AppBar(
        title: const Text('İlgi Alanların'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1728),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF58E6D9)),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      children: [
                        const Text(
                          'Sana daha uygun içerikleri öne çıkaralım',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Birden fazla alan seçebilirsin. Seçmediğin içerikler kaybolmaz; genel akış çalışmaya devam eder.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        if (!_storageAvailable) ...[
                          const SizedBox(height: 14),
                          const _StorageWarning(),
                        ],
                        const SizedBox(height: 22),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: TrendoraInterestCatalog.all.map((interest) {
                            final selected = _selectedInterestIds.contains(
                              interest.id,
                            );
                            return FilterChip(
                              key: ValueKey(interest.id),
                              label: Text(interest.label),
                              selected: selected,
                              showCheckmark: true,
                              checkmarkColor: const Color(0xFF07111F),
                              selectedColor: const Color(0xFF58E6D9),
                              backgroundColor: const Color(0xFF101D2E),
                              side: BorderSide(
                                color: selected
                                    ? const Color(0xFF58E6D9)
                                    : Colors.white12,
                              ),
                              labelStyle: TextStyle(
                                color: selected
                                    ? const Color(0xFF07111F)
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedInterestIds.add(interest.id);
                                  } else {
                                    _selectedInterestIds.remove(interest.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B1728),
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Şimdi Değil'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF07111F),
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _saving ? 'Kaydediliyor' : 'Tercihleri Kaydet',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF58E6D9),
                              foregroundColor: const Color(0xFF07111F),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StorageWarning extends StatelessWidget {
  const _StorageWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB020).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB020).withValues(alpha: 0.35),
        ),
      ),
      child: const Text(
        'Yerel tercihlere şu anda ulaşılamıyor. Bu adımı geçebilir ve uygulamayı normal şekilde kullanabilirsin.',
        style: TextStyle(color: Color(0xFFFFD18A), height: 1.35),
      ),
    );
  }
}
