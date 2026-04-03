import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'update_checker.dart';
import 'update_dialog.dart';
import 'package:http/http.dart' as http;

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

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final url = response.payload;

      if (url != null && url.isNotEmpty) {
        _NotificationRouter.handle(url);
      }
    },
  );

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
    badge: false,
    sound: true,
  );

  runApp(const MyApp());
}

/// ===============================
/// 🔀 Notification Router
/// ===============================
class _NotificationRouter {
  static InAppWebViewController? _controller;
  static String? _queuedUrl;

  static const String _baseUrl = 'http://ec521.tplinkdns.com:8080';

  static String _normalize(String url) {
    if (url.startsWith('http')) return url;
    if (!url.startsWith('/')) url = '/$url';
    return '$_baseUrl$url';
  }

  static void attach(InAppWebViewController controller) {
    _controller = controller;

    if (_queuedUrl != null) {
      _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(_queuedUrl!)));
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

    _controller!.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
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
  InAppWebViewController? _webViewController;

  bool _isLoading = false;
  bool _showBackButton = false;
  bool _openedSetting = false;

  String? _pendingUrl;

  String _currentUrl = ""; // 🔥 여기 추가

  static const String _baseUrl = 'http://ec521.tplinkdns.com:8080';
  static const String _homeUrl =
      'http://ec521.tplinkdns.com:8080/m/main/index.html';
  static const String _loginUrl =
      'http://ec521.tplinkdns.com:8080/m/member/member_login.html';
  String _startUrl = _loginUrl;

  @override
  void initState() {
    super.initState();
    fetchUnreadCount().then(updateBadge); // 🔥 추가
    _checkLoginStatus();

    _checkUpdatePopup();
    WidgetsBinding.instance.addObserver(this);
    _setupFcmListeners();

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _webViewController?.evaluateJavascript(
        source:
            "window.onFlutterFCMToken && window.onFlutterFCMToken('$newToken');",
      );
    });
  }

  Future<int> fetchUnreadCount() async {
    try {
      final res = await http.get(Uri.parse("$_baseUrl/api/unread_count.php"));
      return int.tryParse(res.body) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  void updateBadge(int count) async {
    // iOS는 서버 badge 사용 → 여기선 아무것도 안함
    // Android 대응하려면 나중에 별도 처리
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

    await _webViewController?.evaluateJavascript(
      source:
          """
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
      """,
    );
  }

  /// 🔄 설정 다녀오면 자동 새로고침
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      AuthorizationStatus? finalStatus;
      final count = await fetchUnreadCount();
      updateBadge(count);
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

      await _webViewController?.evaluateJavascript(
        source:
            """
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
        """,
      );
    }
  }

  Future<void> _checkLoginStatus() async {
    // 일단 로그인 페이지 먼저 로드
    _startUrl = _loginUrl;

    setState(() {});
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

      await _webViewController?.evaluateJavascript(source: js);
    } catch (e) {
      if (mounted) {
        await _webViewController?.evaluateJavascript(
          source: "alert('카카오 로그인에 실패했습니다. 다시 시도해주세요.');",
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setupFcmListeners() {
    // 🔥 앱 실행 중 → 클릭
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final url = message.data['url'];

      if (url != null && url.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _NotificationRouter.handle(url);
        });
      }

      final count = await fetchUnreadCount();
      updateBadge(count);
    });

    // 🔥 앱 종료 상태 → 클릭
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final url = message.data['url'];

        if (url != null && url.isNotEmpty) {
          _NotificationRouter.handle(url);
        }
      }
    });

    // 🔥 포그라운드 수신
    FirebaseMessaging.onMessage.listen((message) async {
      final rawTitle = message.data['title'] ?? "";
      final rawBody = message.data['body'] ?? "";

      final title = rawTitle.replaceAll(r'\\\"', '"').replaceAll(r'\"', '"');

      final body = rawBody
          .replaceAll(r'\\\"', '"')
          .replaceAll(r'\"', '"')
          .replaceAll("\\n", "\n");

      flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
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
        payload: message.data['url']?.toString() ?? '',
      );

      final count = await fetchUnreadCount();
      updateBadge(count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final current = _currentUrl.split('?').first;

        /// 🔥 홈 or 로그인 → 무조건 앱 종료
        if (current == _homeUrl || current == _loginUrl) {
          return true;
        }

        final canGoBack = await _webViewController?.canGoBack() ?? false;

        /// 🔥 뒤로 갈 수 있으면 뒤로
        if (canGoBack) {
          await _webViewController?.goBack();
          return false;
        }

        /// 🔥 그 외는 종료
        return true;
      },
      child: Scaffold(
        appBar: _showBackButton
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    final canGoBack =
                        await _webViewController?.canGoBack() ?? false;

                    if (_currentUrl.startsWith(_homeUrl)) {
                      Navigator.pop(context);
                      return;
                    }

                    if (canGoBack) {
                      await _webViewController?.goBack();
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
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_startUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  useHybridComposition: true,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  userAgent: 'Mozilla/5.0 (UrbanFootballApp WebView)',
                ),
                onWebViewCreated: (controller) async {
                  _webViewController = controller;
                  _NotificationRouter.attach(controller);

                  controller.addJavaScriptHandler(
                    handlerName: 'KakaoBridge',
                    callback: (args) async {
                      if (args.isNotEmpty && args.first == 'login') {
                        await _kakaoLogin();
                      }
                      return null;
                    },
                  );

                  /// 🔥🔥 여기 추가 (로그아웃)
                  controller.addJavaScriptHandler(
                    handlerName: 'logout',
                    callback: (args) async {
                      // 1. FCM 토큰 삭제
                      await FirebaseMessaging.instance.deleteToken();

                      // 2. 🔥 쿠키 삭제 (핵심)
                      final cookieManager = CookieManager.instance();
                      await cookieManager.deleteAllCookies();

                      // 3. WebView 저장소 삭제
                      await _webViewController?.evaluateJavascript(
                        source: "localStorage.clear(); sessionStorage.clear();",
                      );

                      return null;
                    },
                  );

                  controller.addJavaScriptHandler(
                    handlerName: 'AppChannel',
                    callback: (args) async {
                      if (args.isNotEmpty && args.first == 'openAppSettings') {
                        _openedSetting = true;
                        await openAppSettings();
                      }

                      // 🔥 추가
                      if (args.isNotEmpty && args.first == 'badge_sync') {
                        final count = await fetchUnreadCount();
                        updateBadge(count);
                      }

                      return null;
                    },
                  );
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url?.toString() ?? '';
                  setState(() {
                    _showBackButton = !url.startsWith(_baseUrl);
                  });
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, url) async {
                  _currentUrl = url?.toString() ?? "";
                  _NotificationRouter.attach(controller);

                  final token = await FirebaseMessaging.instance.getToken();

                  if (token != null) {
                    // 🔥 먼저 저장
                    await controller.evaluateJavascript(
                      source: "window.LAST_FCM_TOKEN = '$token';",
                    );

                    // 🔥 딜레이 추가 (핵심)
                    await Future.delayed(const Duration(milliseconds: 300));

                    await controller.evaluateJavascript(
                      source:
                          "window.onFlutterFCMToken && window.onFlutterFCMToken('$token');",
                    );
                  }

                  if (_pendingUrl != null) {
                    _NotificationRouter.handle(_pendingUrl);
                    _pendingUrl = null;
                  }

                  await _checkNotificationPermission();
                  final count = await fetchUnreadCount();
                  updateBadge(count);
                },
                androidOnPermissionRequest:
                    (controller, origin, resources) async {
                      return PermissionRequestResponse(
                        resources: resources,
                        action: PermissionRequestResponseAction.GRANT,
                      );
                    },

                /// 🔥 JS Alert
                onJsAlert: (controller, request) async {
                  await showDialog(
                    context: context,
                    builder: (context) {
                      final uri = Uri.tryParse(request.url.toString());
                      final domain = uri?.origin ?? request.url.toString();

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
                              Text(
                                request.message ?? "",
                                style: const TextStyle(fontSize: 15),
                              ),
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

                  return JsAlertResponse(
                    handledByClient: true,
                    action: JsAlertResponseAction.CONFIRM,
                  );
                },

                /// 🔥 JS Confirm
                onJsConfirm: (controller, request) async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      final uri = Uri.tryParse(request.url.toString());
                      final domain = uri?.origin ?? request.url.toString();

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
                              Text(request.message ?? ""),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text(
                                      "취소",
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 48, 48, 48),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      "확인",
                                      style: TextStyle(
                                        color: Color(0xFF00A86B),
                                      ),
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

                  return JsConfirmResponse(
                    handledByClient: true,
                    action: result == true
                        ? JsConfirmResponseAction.CONFIRM
                        : JsConfirmResponseAction.CANCEL,
                  );
                },

                /// 🔥 JS Prompt
                onJsPrompt: (controller, request) async {
                  final textController = TextEditingController(
                    text: request.defaultValue ?? "",
                  );

                  final result = await showDialog<String?>(
                    context: context,
                    builder: (context) {
                      final uri = Uri.tryParse(request.url.toString());
                      final domain = uri?.origin ?? request.url.toString();

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
                              Text(request.message ?? ""),
                              const SizedBox(height: 12),
                              TextField(
                                controller: textController,
                                autofocus: true,
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, null),
                                    child: const Text(
                                      "취소",
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 48, 48, 48),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      textController.text,
                                    ),
                                    child: const Text(
                                      "확인",
                                      style: TextStyle(
                                        color: Color(0xFF00A86B),
                                      ),
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

                  return JsPromptResponse(
                    handledByClient: true,
                    action: JsPromptResponseAction.CONFIRM,
                    value: result ?? "",
                  );
                },
              ),
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
