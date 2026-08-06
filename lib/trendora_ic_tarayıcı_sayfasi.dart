import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TrendoraIcTarayiciSayfasi extends StatefulWidget {
  const TrendoraIcTarayiciSayfasi({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<TrendoraIcTarayiciSayfasi> createState() =>
      _TrendoraIcTarayiciSayfasiState();
}

class _TrendoraIcTarayiciSayfasiState
    extends State<TrendoraIcTarayiciSayfasi> {
  late final WebViewController _controller;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.url);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            if (target == null ||
                (target.scheme != 'https' && target.scheme != 'http')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      _controller.loadRequest(uri);
    }
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _handleBack() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: _controller.reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
