import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'home_page.dart';
import 'check.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;

  LatLng? selectedLocation;
  String selectedAddress = '';
  GoogleMapController? mapController;

  String _tempName = '';
  String _tempPhone = '';
  String _tempEmail = '';
  String _tempPassword = '';
  String _tempAddress = '';
  LatLng? _tempLocation;
  String _generatedOTP = '';

  final String _serviceId = 'service_rjktsc7';
  final String _templateId = 'template_og87fvp';
  final String _publicKey = 'Mvl5InTSXeJOr_Cdk';

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.help, color: Colors.red),
              SizedBox(width: 8),
              Text('كيف تستخدم ROMANA؟',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _helpStep('1', Icons.person_add, Colors.blue, 'إنشاء حساب',
                    'اضغط على "تسجيل جديد" وأدخل اسمك ورقم جوالك وإيميلك وباسوردك وحدد موقعك'),
                const Divider(),
                _helpStep('2', Icons.login, Colors.green, 'تسجيل الدخول',
                    'لو عندك حساب اضغط "تسجيل دخول" وأدخل رقم جوالك وباسوردك'),
                const Divider(),
                _helpStep('3', Icons.shopping_cart, Colors.orange, 'أضف للسلة',
                    'تصفح المنتجات واختار الكمية واضغط "أضف" لإضافة المنتج للسلة'),
                const Divider(),
                _helpStep('4', Icons.check_circle, Colors.red, 'أتمم طلبك',
                    'اضغط على أيقونة السلة وراجع طلبك واضغط "تأكيد الطلب"'),
                const Divider(),
                _helpStep(
                    '5',
                    Icons.delivery_dining,
                    Colors.purple,
                    'تتبع طلبك',
                    'بعد الطلب تقدر تتابع حالة توصيل طلبك لحظة بلحظة'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('فهمت! 👍', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpStep(String number, IconData icon, Color color, String title,
      String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool isInAseer(LatLng location) {
    return location.latitude >= 17.5 &&
        location.latitude <= 20.5 &&
        location.longitude >= 41.5 &&
        location.longitude <= 44.5;
  }

  String getAddressFromLatLng(LatLng latLng) {
    final lat = latLng.latitude.toStringAsFixed(5);
    final lng = latLng.longitude.toStringAsFixed(5);
    return 'https://maps.google.com/?q=$lat,$lng';
  }

  Future<void> getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;

      Position position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      if (isInAseer(latLng)) {
        final address = getAddressFromLatLng(latLng);
        setState(() {
          selectedLocation = latLng;
          selectedAddress = address;
        });
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذه الخدمة لا تتوفر في هذه المنطقة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد موقعك!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<bool> _sendEmailOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'email': email,
            'otp_code': otp,
            'to_name': _tempName,
          },
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (!_isLogin && selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اختار موقعك على الخريطة أولاً!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        if (_isLogin) {
          await _loginUser();
        } else {
          await _sendOTP();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حصل خطأ! حاول تاني'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendOTP() async {
    final existing = await FirebaseFirestore.instance
        .collection('customers')
        .where('رقم الجوال', isEqualTo: _phoneController.text)
        .get();

    if (existing.docs.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الجوال مسجل بالفعل!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _tempName = _nameController.text;
    _tempPhone = _phoneController.text;
    _tempEmail = _emailController.text;
    _tempPassword = _passwordController.text;
    _tempAddress = getAddressFromLatLng(selectedLocation!);
    _tempLocation = selectedLocation;
    _generatedOTP = _generateOTP();

    final sent = await _sendEmailOTP(_tempEmail, _generatedOTP);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال كود التحقق على إيميلك! ✅'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPScreen(
            generatedOTP: _generatedOTP,
            onVerified: _completeRegistration,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل إرسال الكود! تأكد من الإيميل'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _completeRegistration() async {
    final docRef =
        await FirebaseFirestore.instance.collection('customers').add({
      'اسم': _tempName,
      'عنوان': _tempAddress,
      'رقم الجوال': _tempPhone,
      'إيميل': _tempEmail,
      'باسورد': _tempPassword,
      'محفظة': '0',
      'موقع': {
        'lat': _tempLocation!.latitude,
        'lng': _tempLocation!.longitude,
      },
      'آخر طلب': '',
      'تاريخ التسجيل': DateTime.now().toString(),
      'آخر دخول': DateTime.now().toString(),
    });

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(docRef.id)
        .collection('addresses')
        .add({
      'اسم': 'المنزل',
      'عنوان': _tempAddress,
      'lat': _tempLocation!.latitude,
      'lng': _tempLocation!.longitude,
      'createdAt': DateTime.now().toString(),
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customerId', docRef.id);
    await prefs.setString('name', _tempName);
    await prefs.setString('address', _tempAddress);
    await prefs.setString('phone', _tempPhone);
    await prefs.setDouble('lat', _tempLocation!.latitude);
    await prefs.setDouble('lng', _tempLocation!.longitude);
    await prefs.setString('lastLoginDate', DateTime.now().toString());

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          name: _tempName,
          email: _tempAddress,
        ),
      ),
    );
  }

  Future<void> _loginUser() async {
    final existing = await FirebaseFirestore.instance
        .collection('customers')
        .where('رقم الجوال', isEqualTo: _phoneController.text)
        .get();

    if (existing.docs.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الجوال غير مسجل!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = existing.docs.first.data();
    final storedPassword = data['باسورد'] ?? '';

    if (storedPassword != _passwordController.text) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('باسورد غلط!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final customerId = existing.docs.first.id;
    final name = data['اسم'] ?? '';
    final address = data['عنوان'] ?? '';

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .update({'آخر دخول': DateTime.now().toString()});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customerId', customerId);
    await prefs.setString('name', name);
    await prefs.setString('address', address);
    await prefs.setString('phone', _phoneController.text);
    await prefs.setString('lastLoginDate', DateTime.now().toString());

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(name: name, email: address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 60),

                // زرار المساعدة
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.help_outline,
                        color: Colors.red, size: 28),
                    onPressed: _showHelpDialog,
                    tooltip: 'مساعدة',
                  ),
                ),

                const Icon(Icons.shopping_cart, size: 80, color: Colors.red),
                const SizedBox(height: 10),
                const Text('ROMANA',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const Text('خضروات وفواكه طازجة',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isLogin ? Colors.red : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'تسجيل دخول',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isLogin ? Colors.white : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  !_isLogin ? Colors.red : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'تسجيل جديد',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isLogin ? Colors.white : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'الاسم',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person, color: Colors.red),
                      filled: true,
                      fillColor: Colors.red.shade50,
                    ),
                    validator: (v) =>
                        !_isLogin && v!.isEmpty ? 'أدخل اسمك' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'رقم الجوال',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.phone, color: Colors.red),
                    filled: true,
                    fillColor: Colors.red.shade50,
                  ),
                  validator: (v) => v!.length < 9 ? 'أدخل رقم جوال صحيح' : null,
                ),
                const SizedBox(height: 16),

                if (!_isLogin) ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'الإيميل',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.email, color: Colors.red),
                      filled: true,
                      fillColor: Colors.red.shade50,
                    ),
                    validator: (v) => !_isLogin && !v!.contains('@')
                        ? 'أدخل إيميل صحيح'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'الباسورد',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock, color: Colors.red),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.red,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: Colors.red.shade50,
                  ),
                  validator: (v) => v!.length < 6
                      ? 'الباسورد لازم يكون 6 أحرف على الأقل'
                      : null,
                ),
                const SizedBox(height: 16),

                if (!_isLogin) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: getCurrentLocation,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                topLeft: Radius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.my_location, color: Colors.red),
                                SizedBox(width: 8),
                                Text('اختر موقعك الحالي',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          child: SizedBox(
                            height: 250,
                            child: GoogleMap(
                              initialCameraPosition: const CameraPosition(
                                target: LatLng(18.2164, 42.5053),
                                zoom: 10,
                              ),
                              onMapCreated: (controller) {
                                mapController = controller;
                              },
                              onTap: (latLng) {
                                if (isInAseer(latLng)) {
                                  final address = getAddressFromLatLng(latLng);
                                  setState(() {
                                    selectedLocation = latLng;
                                    selectedAddress = address;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'هذه الخدمة لا تتوفر في هذه المنطقة'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              markers: selectedLocation != null
                                  ? {
                                      Marker(
                                        markerId: const MarkerId('selected'),
                                        position: selectedLocation!,
                                      )
                                    }
                                  : {},
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedLocation != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('تم تحديد الموقع ✅',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isLogin ? 'دخول' : 'إرسال كود التحقق',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
