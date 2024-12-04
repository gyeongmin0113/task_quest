import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'calendar_page.dart';
import 'today_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _nickname;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    setState(() {
      _nickname = userDoc['nickname'] ?? '';
      final rawUrl = userDoc['profileImageUrl'] ?? '';
      // Add alt=media to the image URL
      _profileImageUrl = rawUrl.isNotEmpty ? '$rawUrl&alt=media' : '';
    });
  }

  Future<void> _updateProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage == null) return;

    final storageRef =
    FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');

    try {
      if (kIsWeb) {
        // Flutter Web: Use putData
        final imageData = await pickedImage.readAsBytes();
        await storageRef.putData(imageData);
      } else {
        // Mobile (iOS/Android): Use putFile
        final file = File(pickedImage.path);
        await storageRef.putFile(file);
      }

      final rawUrl = await storageRef.getDownloadURL();
      final imageUrl = '$rawUrl&alt=media'; // Add alt=media to the URL

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImageUrl': rawUrl});

      setState(() {
        _profileImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진이 업데이트되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 사진 업데이트 실패: $e')),
      );
    }
  }

  Future<void> _updateNickname(String newNickname) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'nickname': newNickname});

    setState(() {
      _nickname = newNickname;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('닉네임이 업데이트되었습니다.')),
    );
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'points': 0, 'completed_tasks': 0, 'total_tasks': 0};
    }

    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      return {'points': 0, 'completed_tasks': 0, 'total_tasks': 0};
    }

    return {
      'points': userDoc['points'] ?? 0,
      'completed_tasks': userDoc['completed_tasks'] ?? 0,
      'total_tasks': userDoc['total_tasks'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('로그인이 필요합니다.'))
          : FutureBuilder<Map<String, dynamic>>(
        future: getUserStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('사용자 정보를 불러올 수 없습니다.'));
          }

          final stats = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_profileImageUrl != null &&
                    _profileImageUrl!.isNotEmpty)
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(_profileImageUrl!),
                  )
                else
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person),
                  ),
                TextButton(
                  onPressed: _updateProfileImage,
                  child: const Text('프로필 사진 변경'),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration:
                  const InputDecoration(labelText: '닉네임'),
                  controller:
                  TextEditingController(text: _nickname),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      _updateNickname(value.trim());
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('이메일: ${user.email}',
                    style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                Text('총 포인트: ${stats['points']}'),
                const SizedBox(height: 8),
                Text('완료된 작업 수: ${stats['completed_tasks']}'),
                const SizedBox(height: 8),
                Text('총 작업 수: ${stats['total_tasks']}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/store'),
                  child: const Text('포인트 상점으로 이동'),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CalendarPage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => TodayPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '달력',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: '오늘',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: '정보',
          ),
        ],
      ),
    );
  }
}