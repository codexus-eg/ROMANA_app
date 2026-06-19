import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;

  // تسجيل أو تسجيل دخول العميل
  static Future<String> loginCustomer({
    required String name,
    required String address,
    required String phone,
  }) async {
    // شوف لو موجود قبل كده برقم التليفون
    final existing = await _db
        .collection('customers')
        .where('phone', isEqualTo: phone)
        .get();

    if (existing.docs.isNotEmpty) {
      // موجود → رجع الـ ID بتاعه
      return existing.docs.first.id;
    } else {
      // مش موجود → سجله جديد
      final doc = await _db.collection('customers').add({
        'name': name,
        'address': address,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    }
  }
}
