import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // Loome kontrolleri, määrame JavaScripti režiimi ja laadime URL-i
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://www.irontrack.ee'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IronTrack',
      theme: ThemeData(
        primarySwatch: Colors.grey,
      ),
      home: Scaffold(
        body: SafeArea(
          child: WebViewWidget(
            controller: _controller,
          ),
        ),
      ),
    );
  }
}