
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'theme_provider.dart';

class StorePage extends StatelessWidget {
  const StorePage({Key? key}) : super(key: key);

  Future<void> _purchaseItem(
      String itemId, int price, String type, BuildContext context) async {
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

      // 포인트 차감 및 아이템 구매 처리
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("포인트 상점")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('store_items').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("상점에 아이템이 없습니다."));
          }

          final items = snapshot.data!.docs;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final itemName = item['name'];
              final itemPrice = item['price'];
              final itemType = item['type'];

              return ListTile(
                title: Text(itemName),
                subtitle: Text("가격: $itemPrice 포인트"),
                trailing: ElevatedButton(
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
                      await _purchaseItem(item.id, itemPrice, itemType, context);
                    }
                  },
                  child: const Text("구매"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
