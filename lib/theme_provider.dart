import 'package:flutter/material.dart';

String BLUE_theme = 'xWg4naDhQPCpokmpJoJL';
String DEEP_theme = '4MxYcvwXrbTStXtL9kPn';
String PINK_theme = 'aixxHvlEmEJXYIVT3Uw3';
String GREEN_theme = 'hyu0HmZXawutFuToNuTc';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // 초기 테마 모드
  ThemeData _themeData = ThemeData.light(); // 초기 테마 데이터
  String _currentThemeId = ''; // 현재 적용된 테마의 ID

  ThemeMode get themeMode => _themeMode;
  ThemeData get themeData => _themeData;
  String get currentThemeId => _currentThemeId; // 현재 테마 ID를 반환하는 getter

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    if (mode == ThemeMode.light) {
      _themeData = ThemeData.light();
    } else if (mode == ThemeMode.dark) {
      _themeData = ThemeData.dark();
    }
    notifyListeners();
  }  // 기본 라이트/다크테마

  void setTheme(String theme) {
    if (theme == DEEP_theme) {
      // 딥다크 테마 정의
      _themeData = ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurple,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
        ),
      );
      _currentThemeId = DEEP_theme; // 테마 ID 저장
    } else if (theme == BLUE_theme) {
      print("블루테마적용");
      _themeData = ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.lightBlue[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
        ),
      );
      _currentThemeId = BLUE_theme; // 테마 ID 저장
    } else if (theme == GREEN_theme) {
      print("그린테마적용");
      _themeData = ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.lightGreen[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
        ),
      );
      _currentThemeId = GREEN_theme; // 테마 ID 저장
    } else if (theme == PINK_theme) {
      print("핑크테마적용");
      _themeData = ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.pink[300],
        scaffoldBackgroundColor: Colors.pink[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.pink[300],
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
        ),
      );
      _currentThemeId = PINK_theme; // 테마 ID 저장
    } else {
      // 기본 라이트 테마
      _themeData = ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
        ),
      );
      _currentThemeId = ''; // 기본 테마는 ID를 비워둠
    }
    notifyListeners();
  }
}
