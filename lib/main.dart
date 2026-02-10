import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'update_checker.dart';
import 'update_dialog.dart';

/// ===============================
/// 🔔 Local Notifications (v20 API)
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  /// background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  /// Local notification init (v20)
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      _NotificationRouter.handle(response.payload);
    },
  );

  /// Android notification channel
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// permission (iOS 필수)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  /// iOS foreground 표시
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const MyApp());
}

/// ===============================
/// Notification Router
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
/// App
/// ===============================
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

/// ===============================
/// WebView Page
/// ===============================
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;

  /// terminated 상태 진입용
  String? _pendingUrl;

  @override
  void initState() {
    super.initState();

    _setupFcmListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await shouldShowUpdatePopup()) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => const UpdateDialog(),
        );
      }
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (UrbanFootballApp WebView)')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            _NotificationRouter.attach(_controller);

            /// token 전달
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
          },
        ),
      )
      ..loadRequest(Uri.parse('http://ec521.tplinkdns.com:8080'));
  }

  void _setupFcmListeners() {
    /// terminated → click
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      final url = message?.data['url'];
      if (url != null && url.isNotEmpty) {
        _pendingUrl = url;
      }
    });

    /// background → click
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final url = message.data['url'];
      _NotificationRouter.handle(url);
    });

    /// foreground receive
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;

      /// iOS: OS(AppDelegate)가 표시
      if (!Platform.isAndroid) return;

      /// Android foreground → local notification (v20)
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
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
