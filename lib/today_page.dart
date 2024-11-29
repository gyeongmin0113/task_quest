import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'calendar_page.dart';
import 'userprofile_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({Key? key}) : super(key: key);

  @override
  _TodayPageState createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _tasks = [];

  Future<void> _fetchTodayTasks() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(user.uid)
        .collection('user_tasks')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .where('completed', isEqualTo: false) // 완료되지 않은 작업만 가져오기
        .get();

    setState(() {
      _tasks = querySnapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'id': doc.id,
        };
      }).toList();
    });
  }

  Future<void> _updateUserPoints(int pointsChange) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) return;

      final currentPoints = snapshot['points'] ?? 0;
      transaction.update(userDoc, {
        'points': currentPoints + pointsChange,
      });
    });
  }

  Future<void> _modifyTask(String taskId, int pointsChange, {bool deleteTask = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userTasks = FirebaseFirestore.instance
          .collection('tasks')
          .doc(user.uid)
          .collection('user_tasks');

      if (deleteTask) {
        await userTasks.doc(taskId).delete();
      } else {
        await userTasks.doc(taskId).update({'completed': true});
      }

      await _fetchTodayTasks();

      setState(() {
        if (deleteTask) {
          _tasks.removeWhere((task) => task['id'] == taskId);
        } else {
          _tasks = _tasks.where((task) => task['id'] != taskId).toList();
        }
      });

      await _updateUserPoints(pointsChange);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleteTask ? '작업이 삭제되었습니다.' : '작업이 완료되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleteTask ? '삭제 실패: $e' : '작업 완료 실패: $e')),
      );
    }
  }

  Future<void> _editTask(String taskId, String currentTitle) async {
    final TextEditingController _taskController = TextEditingController(text: currentTitle);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('작업 수정'),
        content: TextField(
          controller: _taskController,
          decoration: const InputDecoration(labelText: '작업 제목 입력'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final newTitle = _taskController.text.trim();
              if (newTitle.isNotEmpty) {
                try {
                  final user = _auth.currentUser;
                  if (user == null) return;

                  await FirebaseFirestore.instance
                      .collection('tasks')
                      .doc(user.uid)
                      .collection('user_tasks')
                      .doc(taskId)
                      .update({'title': newTitle});

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('작업이 수정되었습니다.')),
                  );
                  await _fetchTodayTasks();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('수정 실패: $e')),
                  );
                }
              }
              Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchTodayTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 일정'),
      ),
      body: _tasks.isEmpty
          ? const Center(child: Text('오늘의 일정이 없습니다.'))
          : ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return ListTile(
            title: Text(task['title']),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editTask(task['id'], task['title']),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _modifyTask(task['id'], 10, deleteTask: false),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _modifyTask(task['id'], -5, deleteTask: true),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const CalendarPage()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserProfilePage()),
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
