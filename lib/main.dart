import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';  // 권한 처리 패키지 추가
import 'dart:io';  // Platform 사용을 위한 import

import 'login_page.dart';
import 'signup_page.dart';
import 'calendar_page.dart';
import 'userprofile_page.dart';
import 'store_page.dart'; // 포인트 상점
import 'firebase_options.dart';
import 'theme_provider.dart'; // 테마 제공

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _initializeNotifications();
  await _requestExactAlarmPermission();  // 권한 요청
  runApp(const TaskQuestApp());
}

// 알림 초기화
Future<void> _initializeNotifications() async {
  const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  // iOS 초기화 설정 (알림 권한 요청 포함)
  final darwinInitializationSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  final initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
    iOS: darwinInitializationSettings, // iOS 알림 설정 추가
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 권한 요청 호출
  await _requestNotificationPermission(); // iOS 알림 권한 요청 추가
}

// 알림 권한 요청 함수
Future<void> _requestNotificationPermission() async {
  if (Platform.isIOS) {
    final status = await Permission.notification.request(); // iOS 알림 권한 요청
    if (status.isGranted) {
      print("Notification permission granted on iOS");
    } else {
      print("Notification permission denied on iOS");
    }
  } else {
    final status = await Permission.notification.request();  // 안드로이드 알림 권한 요청
    if (status.isGranted) {
      print("Notification permission granted");
    } else {
      print("Notification permission denied");
    }
  }
}

// Exact Alarm 권한 요청
Future<void> _requestExactAlarmPermission() async {
  PermissionStatus status = await Permission.scheduleExactAlarm.request();  // 알림 권한 요청
  if (status.isGranted) {
    print("Exact Alarm permission granted!");
  } else {
    print("Exact Alarm permission denied!");
  }
}

// 알림 클릭 시 호출되는 함수
Future<void> onSelectNotification(String? payload) async {
  if (payload != null) {
    print("Notification clicked with payload: $payload");
  }
}

class TaskQuestApp extends StatelessWidget {
  const TaskQuestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Task Quest',
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const InitialPage(),
              '/login': (context) => const LoginPage(),
              '/signup': (context) => const SignupPage(),
              '/home': (context) => const CalendarPage(),
              '/profile': (context) => const UserProfilePage(),
              '/store': (context) => const StorePage(), // 포인트 상점 라우트 추가
            },
          );
        },
      ),
    );
  }
}

class InitialPage extends StatelessWidget {
  const InitialPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 400, // 원하는 너비
                height: 400, // 원하는 높이
                child: const Image(
                  image: AssetImage('assets/images/logo.png'),
                  fit: BoxFit.contain, // 이미지를 컨테이너 내부에 맞춤
                ),
              ),
              const Text(
                "Task Quest!",
                style: TextStyle(fontSize: 30.0, color: Colors.blue),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text("로그인하기"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(200, 50),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text("회원가입하기"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(200, 50),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/home'),
                child: const Text("로그인하지 않고 사용하기"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(200, 50),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
