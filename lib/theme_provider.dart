import 'package:flutter/material.dart';

String BLUE_theme = 'xWg4naDhQPCpokmpJoJL';
String DEEP_theme = '4MxYcvwXrbTStXtL9kPn';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light; // 초기 테마 모드
  ThemeData _themeData = ThemeData.light(); // 초기 테마 데이터

  ThemeMode get themeMode => _themeMode;
  ThemeData get themeData => _themeData;

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
    } else if (theme == BLUE_theme){
      print("블루테마적용");
      _themeData =ThemeData(
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
    }
    else {
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
      );}
    notifyListeners();
  }
}
