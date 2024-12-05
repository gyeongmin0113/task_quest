import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'theme_provider.dart';

class StorePage extends StatefulWidget {
  const StorePage({Key? key}) : super(key: key);

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  int points = 0; // 보유 포인트 (Firebase에서 불러올 것)
  String profileImageUrl =
      "https://firebasestorage.googleapis.com/v0/b/taskquest-e1b8b.firebasestorage.app/o/profile_images%2Fdefault.png?alt=media&token=1800c892-73f0-459b-b81a-f4fde82262c1"; // Firebase에서 가져올 이미지
  List<String> purchasedItems = []; // 구매한 아이템 목록

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      setState(() {
        points = userDoc['points'] ?? 0;
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          profileImageUrl = userDoc['profileImageUrl'] ?? profileImageUrl;
        }
        purchasedItems = List<String>.from(userDoc['purchased_items'] ?? []);
      });
    }
  }

  Future<void> _purchaseItem(String itemId, int price, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(userDoc);
      if (!snapshot.exists) return;

      final currentPoints = snapshot['points'] ?? 0;

      if (currentPoints < price) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포인트가 부족합니다.')),
        );
        return;
      }

      transaction.update(userDoc, {
        'points': currentPoints - price,
        'purchased_items': FieldValue.arrayUnion([itemId]),
      });

      setState(() {
        purchasedItems.add(itemId);
        points -= price;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매 완료!')),
      );
    });
  }

  Future<void> _applyItem(String itemId, String type, String? imageUrl) async {
    if (type == 'theme') {
      // 아이템 ID를 사용하여 테마를 적용
      Provider.of<ThemeProvider>(context, listen: false).setTheme(itemId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변경사항이 적용되었습니다!')),
      );
    } else if (type == 'illust') {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDoc.update({'profileImageUrl': imageUrl});

        setState(() {
          profileImageUrl = imageUrl!;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 이미지가 적용되었습니다!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 이미지 적용 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('포인트 상점'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '배경테마'),
              Tab(text: '일러스트 프로필'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(profileImageUrl),
                  ),
                  Text(
                    '💰 $points',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildThemeTab(),
                  _buildIllustTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('store_items')
          .where('type', isEqualTo: 'theme')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("상점에 테마 아이템이 없습니다."));
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final itemName = item['name'];
            final itemPrice = item['price'];
            String colorHex = item['color'];
            final itemColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

            return _buildItemTile(itemName, itemPrice, item.id, 'theme', color: itemColor);
          },
        );
      },
    );
  }

  Widget _buildIllustTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('store_items')
          .where('type', isEqualTo: 'illust')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("상점에 일러스트 프로필 아이템이 없습니다."));
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final itemName = item['name'];
            final itemPrice = item['price'];
            final imageUrl = item['imageUrl'];

            return _buildItemTile(itemName, itemPrice, item.id, 'illust', imageUrl: imageUrl);
          },
        );
      },
    );
  }

  Widget _buildItemTile(String itemName, int price, String itemId, String type,
      {String? imageUrl, Color? color}) {
    final isPurchased = purchasedItems.contains(itemId);

    // 테마 적용 상태 확인 (아이템 ID와 적용된 테마를 비교)
    final isApplied = type == 'theme'
        ? Provider.of<ThemeProvider>(context, listen: false).currentThemeId == itemId
        : profileImageUrl == imageUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (color != null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              )
            else if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported, size: 40, color: Colors.grey);
                  },
                ),
              )
            else
              const Icon(Icons.widgets, size: 40, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(itemName, style: const TextStyle(fontSize: 16)),
                Text('💰 $price', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isPurchased
                ? (isApplied ? Colors.blue[100] : Colors.blue[200]) // 적용하기 버튼 색상
                : Colors.blueAccent, // 구매하기 버튼 색상
            foregroundColor: Colors.black,
          ),
          onPressed: isApplied
              ? null  // 이미 적용된 경우 버튼 비활성화
              : () async {
            if (isPurchased) {
              final applyResult = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('$itemName 적용'),
                  content: const Text('이 아이템을 적용하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
              if (applyResult) {
                await _applyItem(itemId, type, imageUrl);
              }
            } else {
              await _purchaseItem(itemId, price, type);
            }
          },
          child: Text(isPurchased ? (isApplied ? '적용됨' : '적용하기') : '구매하기'),
        ),
      ],
    );
  }
}
