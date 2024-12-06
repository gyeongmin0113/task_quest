import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:uuid/uuid.dart';

import 'calendar_page.dart';
import 'userprofile_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

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

  Future<void> _scheduleNotification(String taskId, String title, DateTime notificationTime) async {
    try {
      final now = DateTime.now(); // 현재 시간
      print("Current local time: $now");

      // 선택한 알림 시간이 이미 지난 경우, 알림이 내일로 설정되게 처리
      if (notificationTime.isBefore(now)) {
        print('알림 시간이 이미 지나갔습니다. 내일로 예약합니다.');
        notificationTime = notificationTime.add(Duration(days: 1));  // 내일로 설정
      }

      // 알림까지 남은 시간 계산 (현재 시간과 설정된 시간 사이의 차이)
      final timeUntilNotification = notificationTime.difference(now);
      print("Time until notification: $timeUntilNotification");

      // 딜레이 후 알림을 즉시 트리거
      await Future.delayed(timeUntilNotification, () async {
        print("Time reached, triggering notification...");

        // 알림 설정
        const androidDetails = AndroidNotificationDetails(
          'task_channel_id',
          'Task Notifications',
          channelDescription: 'Channel for task notifications',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: false,
          enableLights: true,
          enableVibration: true,
        );
        const notificationDetails = NotificationDetails(android: androidDetails);

        var uuid = Uuid();
        var notificationId = uuid.v4(); // 유니크한 ID 사용

        // 알림 트리거
        await flutterLocalNotificationsPlugin.show(
          notificationId.hashCode,
          '작업 알림',
          title,
          notificationDetails,
          payload: taskId,
        );

        print('Notification triggered successfully');
      });

    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }


  // 시간 선택 다이얼로그
  Future<void> _setReminder(Map<String, dynamic> task) async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      final now = DateTime.now();
      final notificationTime = DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      await _scheduleNotification(task['id'], task['title'], notificationTime);
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
