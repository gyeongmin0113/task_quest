  import 'dart:io';
  import 'package:flutter/foundation.dart';
  import 'package:flutter/material.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:firebase_storage/firebase_storage.dart';
  import 'calendar_page.dart';
  import 'today_page.dart';

  String profile_default = 'https://dummyimage.com/600x400/000/fff';

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
      _initializeUserProfile().then((_) => _loadUserProfile());
    }

    Future<void> _initializeUserProfile() async {
      final user = _auth.currentUser;
      if (user == null) {
        print("로그인된 사용자가 없습니다.");
        return;
      }

      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await userDoc.get();

      if (!snapshot.exists) {
        // 사용자 문서가 없을 경우 기본 데이터 생성
        await userDoc.set({
          'name': user.displayName ?? '사용자',
          'email': user.email ?? '이메일 없음',
          'profileImageUrl': profile_default, // 기본 프로필 이미지 URL
          'points': 0,
          'completed_tasks': 0,
          'total_tasks': 0,
        });
        print("기본 사용자 데이터 생성 완료");
      }
    }



    Future<void> _loadUserProfile() async {
      final user = _auth.currentUser;
      if (user == null) {
        print("로그인된 사용자가 없습니다.");
        return;
      }

      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          print("사용자 문서를 찾을 수 없습니다.");
          return;
        }

        final data = userDoc.data();
        print("Firestore 데이터: $data");

        if (!mounted) return;

        setState(() {
          _nickname = data?['name'] ?? ''; // 필드가 없으면 기본값 ''
          _profileImageUrl = data?['profileImageUrl']?.isNotEmpty == true
              ? data!['profileImageUrl']
              : profile_default; // 기본 프로필 이미지 URL
        });

        print("닉네임: $_nickname, 프로필 이미지 URL: $_profileImageUrl");
      } catch (e) {
        print("Firestore에서 사용자 데이터를 불러오는 중 오류 발생: $e");
      }
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

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? '', // 기본 값
          'email': user.email,
          'profileImageUrl': '', // 기본 프로필 이미지 URL
          'points': 0,
          'completed_tasks': 0,
          'total_tasks': 0,
        });

        // Firestore에 원본 URL 저장
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImageUrl': rawUrl,
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
          .update({'name': newNickname});

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
        print("로그인된 사용자가 없습니다.");
        return {'points': 0, 'completed_tasks': 0, 'total_tasks': 0};
      }

      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          print("사용자 문서가 Firestore에 존재하지 않습니다. 기본 데이터를 반환합니다.");
          return {'points': 0, 'completed_tasks': 0, 'total_tasks': 0};
        }

        final data = userDoc.data();
        print("Firestore 데이터: $data");
        return {
          'points': data?['points'] ?? 0,
          'completed_tasks': data?['completed_tasks'] ?? 0,
          'total_tasks': data?['total_tasks'] ?? 0,
        };
      } catch (e) {
        print("Firestore 데이터 로드 중 오류 발생: $e");
        return {'points': 0, 'completed_tasks': 0, 'total_tasks': 0};
      }
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
            if (snapshot.hasError) {
              print("오류 발생: ${snapshot.error}");
              return const Center(child: Text('사용자 정보를 불러오는 중 오류가 발생했습니다.'));
            }
            if (!snapshot.hasData || snapshot.data == null) {
              print("Firestore 데이터가 없습니다.");
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