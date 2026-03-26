import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'update_checker.dart';
import 'update_dialog.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
  'urbanfootball_channel',
  'UrbanFootball',
  description: 'UrbanFootball notifications',
  importance: Importance.high,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  KakaoSdk.init(nativeAppKey: 'c4eccd1ba39a995ee1e328d590538e0f');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const MyApp());
}

/// ===============================
/// 🔀 Notification Router
/// ===============================
class _NotificationRouter {
  static WebViewController? _controller;
  static String? _queuedUrl;

  static const String _baseUrl = 'http://ec521.tplinkdns.com:8080';

  static String _normalize(String url) {
    if (url.startsWith('http')) return url;
    if (!url.startsWith('/')) url = '/$url';
    return '$_baseUrl$url';
  }

  static void attach(WebViewController controller) {
    _controller = controller;

    if (_queuedUrl != null) {
      _controller!.loadRequest(Uri.parse(_queuedUrl!));
      _queuedUrl = null;
    }
  }

  static void handle(String? url) {
    if (url == null || url.isEmpty) return;

    final target = _normalize(url);

    if (_controller == null) {
      _queuedUrl = target;
      return;
    }

    _controller!.loadRequest(Uri.parse(target));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  late final WebViewController _controller;

  bool _isLoading = false;
  bool _showBackButton = false;
  bool _openedSetting = false;

  String? _pendingUrl;

  static const String _baseUrl = 'http://ec521.tplinkdns.com:8080';
  static const String _homeUrl = 'http://ec521.tplinkdns.com:8080';

  @override
  void initState() {
    super.initState();

    _checkUpdatePopup(); // 🔥 버전 확인

    WidgetsBinding.instance.addObserver(this);

    _setupFcmListeners();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (UrbanFootballApp WebView)')
      /// 🔥 alert 처리
      /// ===============================
      /// 🔥 JS Alert
      /// ===============================
      ..setOnJavaScriptAlertDialog((
        JavaScriptAlertDialogRequest request,
      ) async {
        await showDialog(
          context: context,
          builder: (context) {
            final uri = Uri.tryParse(request.url ?? "");
            final domain = uri?.origin ?? request.url ?? "";

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "'$domain' 페이지 내용:",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(request.message, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "확인",
                          style: TextStyle(
                            color: Color(0xFF00A86B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      })
      /// ===============================
      /// 🔥 JS Confirm
      /// ===============================
      ..setOnJavaScriptConfirmDialog((
        JavaScriptConfirmDialogRequest request,
      ) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (context) {
            final uri = Uri.tryParse(request.url ?? "");
            final domain = uri?.origin ?? request.url ?? "";

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "'$domain' 페이지 내용:",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(request.message),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              color: Color.fromARGB(255, 48, 48, 48),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            "확인",
                            style: TextStyle(color: Color(0xFF00A86B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        return result ?? false;
      })
      /// ===============================
      /// 🔥 JS Prompt
      /// ===============================
      ..setOnJavaScriptTextInputDialog((
        JavaScriptTextInputDialogRequest request,
      ) async {
        final controller = TextEditingController(
          text: request.defaultText ?? "",
        );

        final result = await showDialog<String?>(
          context: context,
          builder: (context) {
            final uri = Uri.tryParse(request.url ?? "");
            final domain = uri?.origin ?? request.url ?? "";

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "'$domain' 페이지 내용:",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(request.message),

                    const SizedBox(height: 12),

                    TextField(controller: controller, autofocus: true),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              color: Color.fromARGB(255, 48, 48, 48),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          child: const Text(
                            "확인",
                            style: TextStyle(color: Color(0xFF00A86B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        return result ?? "";
      })
      /// 🔹 Kakao Bridge 유지
      ..addJavaScriptChannel(
        'KakaoBridge',
        onMessageReceived: (message) async {
          if (message.message == 'login') {
            await _kakaoLogin();
          }
        },
      )
      /// 🔹 설정 이동 브릿지 추가
      ..addJavaScriptChannel(
        'AppChannel',
        onMessageReceived: (message) async {
          if (message.message == "openAppSettings") {
            _openedSetting = true;
            await openAppSettings();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            setState(() {
              _showBackButton = !url.startsWith(_baseUrl);
            });
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) async {
            _NotificationRouter.attach(_controller);

            final token = await FirebaseMessaging.instance.getToken();

            if (token != null) {
              _controller.runJavaScript(
                "window.onFlutterFCMToken && window.onFlutterFCMToken('$token');",
              );
            }

            if (_pendingUrl != null) {
              _NotificationRouter.handle(_pendingUrl);
              _pendingUrl = null;
            }

            /// 🔔 권한 체크
            await _checkNotificationPermission();
          },
        ),
      );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadRequest(Uri.parse(_homeUrl));
    });
  }

  /// 앱 버전 확인
  Future<void> _checkUpdatePopup() async {
    final show = await shouldShowUpdatePopup();
    if (!show) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(),
    );
  }

  /// 🔔 권한 체크 (기존 구조 유지 + 즉시 반영 개선)
  Future<void> _checkNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    final isAuthorized =
        settings.authorizationStatus == AuthorizationStatus.authorized;

    await _controller.runJavaScript("""
      (function(){
        var banner = document.getElementById('devicePushBanner');
        if(!banner) return;

        banner.style.transition = "opacity 0.15s ease";

        if (${isAuthorized ? "true" : "false"}) {
          banner.style.opacity = "0";
          setTimeout(function(){
            banner.style.display = "none";
          },150);
        } else {
          banner.style.display = "block";
          banner.style.opacity = "1";
        }
      })();
    """);
  }

  /// 🔄 설정 다녀오면 자동 새로고침
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      AuthorizationStatus? finalStatus;

      // 🔥 최대 1초 동안 100ms 간격으로 권한 상태 확인
      for (int i = 0; i < 10; i++) {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();

        finalStatus = settings.authorizationStatus;

        // 상태가 확정되면 즉시 탈출
        if (finalStatus == AuthorizationStatus.authorized ||
            finalStatus == AuthorizationStatus.denied) {
          break;
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      final isAuthorized = finalStatus == AuthorizationStatus.authorized;

      await _controller.runJavaScript("""
        (function(){
          var banner = document.getElementById('devicePushBanner');
          if(!banner) return;

          banner.style.transition = "opacity 0.15s ease";

          if ($isAuthorized) {
            banner.style.opacity = "0";
            banner.style.display = "none";
          } else {
            banner.style.display = "block";
            banner.style.opacity = "1";
          }

          banner.offsetHeight; // 🔥 강제 reflow
        })();
      """);
    }
  }

  Future<void> _kakaoLogin() async {
    try {
      setState(() => _isLoading = true);

      OAuthToken token;

      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      final user = await UserApi.instance.me();

      final js =
          """
fetch('/result/member_login_ok.php', {
  method: 'POST',
  headers: {'Content-Type': 'application/x-www-form-urlencoded'},
  body: new URLSearchParams({
    mode: 'member_sns_login',
    site: 'cacao',
    id: '${user.id}',
    nick_name: '${user.kakaoAccount?.profile?.nickname ?? ""}',
    email: '${user.kakaoAccount?.email ?? ""}',
    access_token: '${token.accessToken}',
    type: 'login'
  })
})
.then(res => res.text())
.then(data => {
  if (data.includes("ok|!|")) {
    window.location.href='/m/main/index.html';
  } else if (data.includes("new|!|")) {
    window.location.href='/m/member/member_join.html';
  } else {
    alert("로그인 실패");
  }
});
""";

      await _controller.runJavaScript(js);
    } catch (e) {
      if (mounted) {
        await _controller.runJavaScript(
          "alert('카카오 로그인에 실패했습니다. 다시 시도해주세요.');",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupFcmListeners() {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      final url = message?.data['url'];
      if (url != null && url.isNotEmpty) {
        _pendingUrl = url;
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _NotificationRouter.handle(message.data['url']);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      if (!Platform.isAndroid) return;

      final raw = message.notification?.body ?? "";

      final body = raw.replaceAll("\\n", "\n");

      flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        message.notification?.title ?? "",
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _showBackButton
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (await _controller.canGoBack()) {
                      _controller.goBack();
                    }
                  },
                ),
              )
            : null,
        body: SafeArea(
          top: true,
          bottom: true,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const ColoredBox(
                  color: Color(0x80000000),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00CD00),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
