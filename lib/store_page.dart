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
  String profileImageUrl = "https://picsum.photos/288/364"; // Firebase에서 가져올 이미지

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
        profileImageUrl = userDoc['profileImageUrl'] ?? profileImageUrl;
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구매 완료!')),
      );

      // 테마 아이템 적용
      if (type == 'theme') {
        Provider.of<ThemeProvider>(context, listen: false).setTheme(itemId);
      }

      setState(() {
        points -= price;
      });
    });
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
              Tab(text: '스티커'),
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
                  _buildStickerTab(),
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

            return _buildItemTile(itemName, itemPrice, item.id, 'theme');
          },
        );
      },
    );
  }

  Widget _buildStickerTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('store_items')
          .where('type', isEqualTo: 'sticker')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("상점에 스티커 아이템이 없습니다."));
        }

        final items = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final itemName = item['name'];
            final itemPrice = item['price'];

            return _buildItemTile(itemName, itemPrice, item.id, 'sticker');
          },
        );
      },
    );
  }

  Widget _buildItemTile(String itemName, int price, String itemId, String type) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.widgets, size: 40, color: Colors.blueAccent),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('$itemName 구매'),
                content: const Text('이 아이템을 구매하시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('구매'),
                  ),
                ],
              ),
            );

            if (result == true) {
              await _purchaseItem(itemId, price, type);
            }
          },
          child: const Text('구매하기'),
        ),
      ],
    );
  }
}
