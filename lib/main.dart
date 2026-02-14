import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// ===============================
/// 🔔 Local Notifications
/// ===============================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel androidChannel = AndroidNotificationChannel(
  'urbanfootball_channel',
  'UrbanFootball',
  description: 'UrbanFootball notifications',
  importance: Importance.high,
);

/// ===============================
/// 🔔 Background FCM handler
/// ===============================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// ===============================
/// MAIN
/// ===============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
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
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
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

/// ===============================
/// APP
/// ===============================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
return MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue, // ← 원하는 색
    ),
  ),
  home: const WebViewPage(),
);
  }
}

/// ===============================
/// 🌐 WebView Page
/// ===============================
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  String? _pendingUrl;

  static const String _homeUrl = 'http://ec521.tplinkdns.com:8080';

  @override
  void initState() {
    super.initState();

    _setupFcmListeners();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (UrbanFootballApp WebView)')

      /// 🔥 alert 처리
      ..setOnJavaScriptAlertDialog(
        (JavaScriptAlertDialogRequest request) async {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("알림"),
              content: Text(request.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("확인"),
                ),
              ],
            ),
          );
        },
      )

      /// 🔥 confirm 처리
      ..setOnJavaScriptConfirmDialog(
        (JavaScriptConfirmDialogRequest request) async {
          return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("확인"),
                  content: Text(request.message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("취소"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("확인"),
                    ),
                  ],
                ),
              ) ??
              false;
        },
      )

      /// 🔥 prompt 처리 (컴파일 오류 수정 완료)
      ..setOnJavaScriptTextInputDialog(
        (JavaScriptTextInputDialogRequest request) async {
          final controller =
              TextEditingController(text: request.defaultText ?? "");

          final result = await showDialog<String?>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("입력"),
              content: TextField(
                controller: controller,
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("취소"),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text),
                  child: const Text("확인"),
                ),
              ],
            ),
          );

          return result ?? "";
        },
      )

      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            _NotificationRouter.attach(_controller);

            final token =
                await FirebaseMessaging.instance.getToken();

            if (token != null) {
              _controller.runJavaScript(
                "window.onFlutterFCMToken && window.onFlutterFCMToken('$token');",
              );
            }

            if (_pendingUrl != null) {
              _NotificationRouter.handle(_pendingUrl);
              _pendingUrl = null;
            }
          },
        ),
      );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadRequest(Uri.parse(_homeUrl));
    });
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
      final notification = message.notification;
      if (notification == null) return;
      if (!Platform.isAndroid) return;

      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['url'],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
