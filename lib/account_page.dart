import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final TextEditingController _nameController = TextEditingController();
  String phone = '';
  String email = '';
  String customerId = '';
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    customerId = prefs.getString('customerId') ?? '';
    _nameController.text = prefs.getString('name') ?? '';

    if (customerId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(customerId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          if (mounted) {
            setState(() {
              // تم تعديل السطر ده عشان يقرأ الإيميل صح ومياخدش العنوان كبديل
              phone = data['رقم_الهاتف'] ??
                  data['phone'] ??
                  prefs.getString('phone') ??
                  'غير متوفر';
              email = data['البريد'] ??
                  data['email'] ??
                  prefs.getString('email') ??
                  'لا يوجد بريد إلكتروني';
            });
          }
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || customerId.isEmpty) return;

    setState(() => isSaving = true);
    try {
      // تحديث الاسم في الفايربيز
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .set({'الاسم': newName, 'name': newName}, SetOptions(merge: true));

      // تحديث الاسم في الذاكرة المحلية
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الاسم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء تحديث الاسم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => isSaving = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    }
  }

  Future<void> _deleteAccount() async {
    // إظهار رسالة تأكيد قبل الحذف
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الحساب', style: TextStyle(color: Colors.red)),
          content: const Text(
              'هل أنت متأكد من رغبتك في حذف الحساب نهائياً؟ سيتم مسح جميع بياناتك ولن تتمكن من استرجاعها.'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('نعم، احذف',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && customerId.isNotEmpty) {
      try {
        // حذف من الفايرستور
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(customerId)
            .delete();
        // حذف من Authentication لو موجود
        if (FirebaseAuth.instance.currentUser != null) {
          await FirebaseAuth.instance.currentUser!.delete();
        }
        // تفريغ الذاكرة والعودة للتسجيل
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('حدث خطأ، قد تحتاج لتسجيل الدخول مجدداً لإتمام الحذف'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: const Text('حسابي',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 32),

                    // حقل تعديل الاسم
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم',
                        prefixIcon: const Icon(Icons.edit, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // زر حفظ الاسم
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSaving ? null : _updateName,
                        child: isSaving
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('حفظ تغيير الاسم',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // حقل رقم الهاتف (للقراءة فقط)
                    _buildInfoTile(Icons.phone, 'رقم الهاتف', phone),
                    const SizedBox(height: 16),

                    // حقل الإيميل (للقراءة فقط)
                    _buildInfoTile(Icons.email, 'البريد الإلكتروني', email),

                    const SizedBox(height: 48),

                    // أزرار الخروج والحذف
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('تسجيل خروج',
                            style: TextStyle(color: Colors.red, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.grey),
                        label: const Text('حذف الحساب نهائياً',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _deleteAccount,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
