import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'calendar_page.dart';
import 'today_page.dart';
import 'userprofile_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  Future<Map<String, dynamic>> getUserStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'points': 0, 'completed_tasks': 0, 'total_tasks': 0};

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return {'points': 0, 'completed_tasks': 0, 'total_tasks': 0};

    return {
      'points': userDoc['points'] ?? 0,
      'completed_tasks': userDoc['completed_tasks'] ?? 0,
      'total_tasks': userDoc['total_tasks'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Quest Dashboard'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
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
                Text('총 포인트: ${stats['points']}'),
                Text('완료된 작업 수: ${stats['completed_tasks']}'),
                Text('총 작업 수: ${stats['total_tasks']}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TodayPage()),
                    );
                  },
                  child: const Text('오늘의 일정 보기'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CalendarPage()),
                    );
                  },
                  child: const Text('캘린더 보기'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const UserProfilePage()),
                    );
                  },
                  child: const Text('프로필 보기'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
