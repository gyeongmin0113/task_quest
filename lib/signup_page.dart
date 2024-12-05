import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


String profile_default = 'https://dummyimage.com/600x400/000/fff';

// 에러 메시지 다이얼로그 표시
void _showErrorDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close),
          ),
        ],
      );
    },
  );
}

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  //String _errorMessage = ''; // 에러 메시지를 저장할 변수

  // 회원가입 처리 함수
  Future<void> _createUser() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String passwordConfirm = _passwordConfirmController.text.trim();

    bool isAlpha = RegExp(r'^[a-zA-Z]+$').hasMatch(password); // 비밀번호가 문자만 포함되어 있는지 확인
    bool isNum = RegExp(r'^[0-9]+$').hasMatch(password); // 비밀번호가 숫자만 포함되어 있는지 확인

    // 이름이 비어있는지 확인
    if (name.isEmpty) {
      _showErrorDialog(context, "오류!", "이름을 입력해야 합니다.");
    }
    // 이메일이 비어있는지 확인
    else if (email.isEmpty) {
      _showErrorDialog(context, "오류!", "이메일을 입력해야 합니다.");
    }
    // 비밀번호가 비어있는지 확인
    else if (password.isEmpty) {
      _showErrorDialog(context, "오류!", "비밀번호를 입력해야 합니다.");
    }
    // 비밀번호 확인란이 비어있는지 확인
    else if (passwordConfirm.isEmpty) {
      _showErrorDialog(context, "오류!", "비밀번호 확인란을 입력해야 합니다.");
    }
    // 비밀번호와 비밀번호 확인란이 일치하는지 확인
    else if (password != passwordConfirm) {
      _showErrorDialog(context, "오류!", "비밀번호가 일치하지 않습니다.");
    }
    // 비밀번호 길이가 12자 이상인 경우 확인
    else if (password.length > 12) {
      _showErrorDialog(context, "오류!", "비밀번호는 12자리 이하여야 합니다.");
    }
    // 비밀번호가 문자와 숫자를 모두 포함해야 함
    else if (isAlpha || isNum) {
      _showErrorDialog(context, "오류!", "비밀번호에는 문자와 숫자가 모두 포함되어야 합니다.");
    }
    else {
      try {
        // Firestore에서 이메일 중복 체크
        var querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .get();

        // 이메일이 이미 존재하는 경우
        if (querySnapshot.docs.isNotEmpty) {
          _showErrorDialog(context, "오류!", "이미 사용 중인 이메일입니다.");
        } else {
          print("here log 1");
          // Firebase에 Authentication으로 사용자 등록
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Firebase UID 가져오기
          String uid = userCredential.user!.uid;
          print("HERE 1: UID: $uid");

          // Firestore에 사용자 정보 추가
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'name': name,
            'email': email,
            'password': password,  // 실제 서비스에서는 비밀번호를 해시화해야 합니다.
            'profileImageUrl': profile_default, // 기본 프로필 설정
            'points' : 0 // 기본 포인트 필드
          });;print("log: Firestore에 사용자 정보 저장 완료");

          // 회원가입 성공 후 /home 화면으로 이동
          Navigator.pushReplacementNamed(context, '/home');
          print("회원가입 성공: $name, $email");
        }
      } catch (e) {
        print("회원가입 중 오류 발생: $e");
        _showErrorDialog(context, "오류!", "회원가입에 실패했습니다. 다시 시도해주세요.");
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "회원가입하기",
              style: TextStyle(fontSize: 30.0),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Text("이름", style: TextStyle(fontSize: 20)),
                // SizedBox(width: 180),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "이름 입력",
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Text("이메일", style: TextStyle(fontSize: 20)),
                // SizedBox(width: 161),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "이메일 입력",
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Text("비밀번호", style: TextStyle(fontSize: 20)),
                // SizedBox(width: 142),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "비밀번호 입력",
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Text("비밀번호 다시 입력하기", style: TextStyle(fontSize: 20)),
                // SizedBox(width: 20),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _passwordConfirmController,
                    obscureText: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "비밀번호 한번 더 입력",
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createUser,
              child: const Text("가입 완료하기"),
            ),
          ],
        ),
      ),
    );
  }
}