// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'services/orders_service.dart';
import 'services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/orders_list_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background message handler. Must be a top-level function.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in the background isolate
  await Firebase.initializeApp();

  // Initialize local notifications for the background isolate
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: androidInitializationSettings);
  try {
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e) {
    // ignore init errors in background
  }

  // Create channel if needed
  try {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'orders_channel',
      'Orders',
      description: 'Notificaciones de pedidos',
      importance: Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  } catch (e) {
    // ignore
  }

  // Show notification if message contains a notification payload
  final notification = message.notification;
  if (notification != null) {
    final androidDetails = AndroidNotificationDetails(
      'orders_channel',
      'Orders',
      channelDescription: 'Notificaciones de pedidos',
      importance: Importance.max,
      priority: Priority.high,
    );
    final platform = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        notification.title,
        notification.body,
        platform);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseInitError;
  try {
    await Firebase.initializeApp();
    // Asegurarse de disponer de un usuario anónimo antes de arrancar la app
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        final userCred = await auth.signInAnonymously();
        debugPrint('Signed in anonymously: ${userCred.user?.uid}');
      } catch (e) {
        debugPrint('Error signing in anonymously: $e');
      }
    } else {
      debugPrint('Already signed in: ${auth.currentUser!.uid}');
    }
  } catch (e) {
    firebaseInitError = e;
    debugPrint('Firebase.initializeApp() failed: $e');
  }

  // Register background handler so messages are handled when the app is in background/killed
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp(firebaseInitError: firebaseInitError));
}

class MyApp extends StatelessWidget {
  final Object? firebaseInitError;
  const MyApp({super.key, this.firebaseInitError});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider<OrdersService>(create: (_) => OrdersService()),
      ],
      child: MaterialApp(
        title: 'Diseño Único',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: firebaseInitError != null
            ? Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error inicializando Firebase:\n${firebaseInitError.toString()}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            : const _Root(),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root({Key? key}) : super(key: key);

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.load();
    // Register FCM token (if available) and configure handlers
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final snack = message.notification?.title ?? 'Notificación';
        if (mounted && snack.isNotEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(snack)));
        }
      });

      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken();
      if (token != null) {
        await auth.setFcmToken(token);
      }
      // Optionally handle token refresh
      fcm.onTokenRefresh.listen((t) async {
        await auth.setFcmToken(t);
      });
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
    // Init local notification service and start listening to orders changes
    try {
      final notif = NotificationService();
      await notif.init();
      await notif.startListening();
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final auth = Provider.of<AuthService>(context);
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }
    return const OrdersListScreen();
  }
}
