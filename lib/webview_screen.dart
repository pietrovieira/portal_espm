import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:webview_flutter/webview_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

// #docregion platform_imports
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS/macOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
// #enddocregion platform_imports

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _WebViewScreen createState() => _WebViewScreen();
}

class _WebViewScreen extends State<WebViewScreen> with WidgetsBindingObserver{
  final urlPage = "https://portal.espm.br";
  final String _msgError = "";

  //String _msgError = "";
  int _progress = 0;
  bool isShowFab = false;
  bool isShowWebview = true;

  late final WebViewController _controller;

  Timer? _timer;
  final int __secondsLeft = 60 * 5;
  int _secondsLeft = 0;

  Future<void> _launchInBrowser(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      if (state == AppLifecycleState.resumed) {
        _resetTimer();
        debugPrint('🎉 O app foi aberto!');
      } else if (state == AppLifecycleState.paused) {
        _stopTimer();
        debugPrint("App foi minimizado (background)");
      } else if (state == AppLifecycleState.inactive) {
        _stopTimer();
        debugPrint("App está inativo");
      } else if (state == AppLifecycleState.detached) {
        _stopTimer();
        debugPrint("App foi encerrado");
      }
    });
  }

  void _startTimer() {
    if ( _secondsLeft == 0) {
      _secondsLeft = __secondsLeft;
    }
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _secondsLeft--;
      });
      //debugPrint('Segundos restantes: $_secondsLeft');

      if (_secondsLeft <= 0) {
        _controller.reload();
        //debugPrint('🎉 O timer de 30 segundos terminou!');
        _resetTimer();  // Reinicia o timer quando chega a 0
      }
    });
  }

  // Método para reiniciar o timer
  void _resetTimer() {
    _stopTimer();
    _startTimer();  // Reinicia o timer com 30 segundos
  }

  void _stopTimer() {
    setState(() {
      _secondsLeft = __secondsLeft;  // Reseta a contagem para 30 segundos
    });
    _timer?.cancel(); // Cancela o timer anterior
  }

  @override
  void initState() {
    super.initState();

    _startTimer();

    WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver); // Registra o observer

    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress;
            });
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            if (error.errorCode == -2) {
    // Erro de conexão com a internet
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Erro de conexão'),
                    content: Text('Verifique sua conexão com a internet.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          _controller.reload();
                        },
                        child: Text('Tentar novamente'),
                      ),
                    ],
                  );
                },
              );
            } else {
              // Outros erros
              _controller.goBack();
            }

            debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          onNavigationRequest: (NavigationRequest request) async {
            if (!request.url.startsWith('/') &&
              !request.url.startsWith("https://login.microsoftonline.com/") &&
              !request.url.startsWith("https://login.live.com/") &&
              !request.url.startsWith("https://acadespmb2c.b2clogin.com/") &&
              !request.url.startsWith("https://portal.espm.br") &&
              !request.url.startsWith("https://login.microsoftonline.com")) {
              await _launchInBrowser(Uri.parse(request.url));
              return NavigationDecision.prevent;
            }
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
            debugPrint('Error occurred on page: ${error.response?.statusCode}');
            if ( error.response?.statusCode == 404 ) {
              setState(() {
                isShowFab = true;
              });
            }
          },
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message.message)));
        },
      )
      ..loadRequest(Uri.parse(urlPage));

    // setBackgroundColor is not currently supported on macOS.
    if (kIsWeb || !Platform.isMacOS) {
      controller.setBackgroundColor(const Color(0x80000000));
    }

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion platform_features

    _controller = controller;
  }

  // Future<void> _launchInBrowserView(Uri url) async {
  //   if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
  //     throw Exception('Could not launch $url');
  //   }
  // }

  // Future<void> _launchInWebView(Uri url) async {
  //   if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
  //     throw Exception('Could not launch $url');
  //   }
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
      child:
          !isShowFab ? _msgError != ''
              ? Center(child: Text('Error Message: $_msgError'))
              : _progress >= 100
              ? WebViewWidget(controller: _controller)
              : Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ) : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "Página não encontrada",
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey, // Or your preferred color
              ),
            ),
            const SizedBox(height: 20), // Add some spacing
            ElevatedButton(
              onPressed: () {
                // Navigate back to the previous screen or home screen.
                //Navigator.pop(context); // Or Navigator.pushNamed(context, '/home');
                _controller.goBack();
                setState(() {
                  isShowFab = false;
                });
              },
              child: const Text("Voltar"),
            ),
             //Optional: Add a fun image or GIF
            // Image.asset(
            //   'assets/images/404_image.png', // Replace with your image path
            //   height: 200, // Adjust height as needed
            // ),
          ],
        ),
      ),
    ),
    );
  }
}