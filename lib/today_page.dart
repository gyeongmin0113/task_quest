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
  int _selectedIndex = 1; // 현재 선택된 버튼 인덱스
  final TextEditingController _taskController = TextEditingController();

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
        SnackBar(content: Text(deleteTask ? '할 일이 삭제되었습니다.' : '할 일이 완료되었습니다.')),
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
        title: const Text('할 일 수정'),
        content: TextField(
          controller: _taskController,
          decoration: const InputDecoration(labelText: '할 일 제목 입력'),
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
                    const SnackBar(content: Text('할 일이 수정되었습니다.')),
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

  Future<void> _addNewTask() async {
    final taskTitle = _taskController.text.trim();
    if (taskTitle.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(user.uid)
          .collection('user_tasks')
          .add({
        'title': taskTitle,
        'date': Timestamp.fromDate(today),
        'completed': false,
      });

      _taskController.clear(); // 입력 필드 비우기
      await _fetchTodayTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새로운 할 일이 추가되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('할 일 추가 실패: $e')),
      );
    }
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
        title: const Text('오늘의 할 일'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                var task = _tasks[index];
                return ListTile(
                  title: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _modifyTask(task['id'], 10),
                      ),
                      Expanded(
                        child: Text(task['title'] ?? '제목 없음'),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editTask(task['id'], task['title']),
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50.0), // 좌우 여백을 16으로 설정
            child: TextField(
              controller: _taskController,
              decoration: InputDecoration(
                labelText: '새로운 할 일',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addNewTask(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _addNewTask,
            child: const Text('할 일 추가하기', style: TextStyle(fontSize: 20)),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(200, 50),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => CalendarPage()));
          } else if (index == 1) {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => TodayPage()));
          } else if (index == 2) {
            Navigator.push(
                context, MaterialPageRoute(builder: (context) => UserProfilePage()));
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '달력'),
          BottomNavigationBarItem(icon: Icon(Icons.today), label: '오늘'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}