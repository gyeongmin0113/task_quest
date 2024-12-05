import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'today_page.dart';
import 'userprofile_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _tasks = [];

  // 라벨 선택을 위한 리스트
  final List<Map<String, dynamic>> _labels = [
    {'label': '개인', 'color': Colors.green},
    {'label': '업무', 'color': Colors.blue},
    {'label': '중요', 'color': Colors.red},
  ];

  Future<void> _fetchTasksForSelectedDay() async {
    if (_selectedDay == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final startOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final endOfDay = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 23, 59, 59);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(user.uid)
        .collection('user_tasks')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .where('completed', isEqualTo: false) // 완료되지 않은 할 일만 가져오기
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

      await _fetchTasksForSelectedDay();

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
        SnackBar(content: Text(deleteTask ? '삭제 실패: $e' : '할 일 완료 실패: $e')),
      );
    }
  }

  Future<void> _addTask(String title, String label) async {
    if (_selectedDay == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final taskData = {
      'title': title,
      'date': Timestamp.fromDate(_selectedDay!),
      'created_at': Timestamp.now(),
      'completed': false,
      'label': label, // 라벨 추가
    };

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(user.uid)
          .collection('user_tasks')
          .add(taskData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할 일이 추가되었습니다.')),
      );

      await _fetchTasksForSelectedDay();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('할 일 추가 실패: $e')),
      );
    }
  }

  Future<void> _editTask(String taskId, String currentTitle, String currentLabel) async {
    final TextEditingController _taskController = TextEditingController(text: currentTitle);
    String selectedLabel = currentLabel; // 현재 선택된 라벨로 초기화

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('할 일 수정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(labelText: '할 일 제목 입력'),
                ),
                DropdownButton<String>(
                  value: selectedLabel,  // 선택된 라벨을 value로 설정
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedLabel = newValue!;  // 선택된 라벨을 갱신
                    });
                  },
                  items: _labels.map<DropdownMenuItem<String>>((label) {
                    return DropdownMenuItem<String>(
                      value: label['label'],
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            color: label['color'],
                          ),
                          const SizedBox(width: 10),
                          Text(label['label']),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
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
                          .update({'title': newTitle, 'label': selectedLabel});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('할 일이 수정되었습니다.')),
                      );
                      await _fetchTasksForSelectedDay();
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
          );
        },
      ),
    );
  }



  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchTasksForSelectedDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이번달 일정'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _fetchTasksForSelectedDay();
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  String taskTitle = '';
                  String selectedLabel = _labels[0]['label']; // 기본 라벨 '개인'으로 설정

                  return StatefulBuilder(
                    builder: (context, setState) {
                      return AlertDialog(
                        title: const Text('할 일 추가'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              onChanged: (value) {
                                taskTitle = value;
                              },
                              decoration: const InputDecoration(labelText: '할 일 입력'),
                            ),
                            DropdownButton<String>(
                              value: selectedLabel,  // 선택된 라벨을 value로 설정
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedLabel = newValue!;  // 선택된 라벨을 갱신
                                });
                              },
                              items: _labels.map<DropdownMenuItem<String>>((label) {
                                return DropdownMenuItem<String>(
                                  value: label['label'],
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        color: label['color'],
                                      ),
                                      const SizedBox(width: 10),
                                      Text(label['label']),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              if (taskTitle.isNotEmpty) {
                                await _addTask(taskTitle, selectedLabel);  // 선택된 라벨과 함께 할 일 추가
                              }
                              Navigator.of(context).pop();
                            },
                            child: const Text('추가'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: Size(200, 50),
              padding: EdgeInsets.zero,
            ),
            child: const Text('할 일 추가', style: TextStyle(fontSize: 20)),
          )
          ,
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return ListTile(
                  leading: Container(
                    width: 10,
                    height: 40,
                    color: _labels.firstWhere((label) => label['label'] == task['label'])['color'],
                  ),
                  title: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _modifyTask(task['id'], 10, deleteTask: false),
                      ),
                      Expanded(child: Text(task['title'])),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editTask(task['id'], task['title'], task['label']),
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
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TodayPage()),
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
            icon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}