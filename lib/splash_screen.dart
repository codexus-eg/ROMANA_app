import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'order_tracking_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _bgController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _bgScale;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _bgScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeOutBack),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5)),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _startAnimations();
  }

  void _startAnimations() async {
    await _bgController.forward();
    await _logoController.forward();
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    _navigate();
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? '';
    final address = prefs.getString('address') ?? '';
    final activeOrderId = prefs.getString('activeOrderId') ?? '';
    final activeOrderAddress = prefs.getString('activeOrderAddress') ?? '';
    final activeOrderTotal = prefs.getDouble('activeOrderTotal') ?? 0.0;
    final lastLoginDate = prefs.getString('lastLoginDate') ?? '';

    if (!mounted) return;

    if (name.isNotEmpty && lastLoginDate.isNotEmpty) {
      final lastLogin = DateTime.parse(lastLoginDate);
      final diff = DateTime.now().difference(lastLogin).inDays;
      if (diff >= 7) {
        await prefs.clear();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
        return;
      }
    }

    if (name.isEmpty) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
      return;
    }

    if (activeOrderId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(activeOrderId)
            .get();

        if (!mounted) return;

        final status = doc.data()?['status'] ?? '';

        if (status == 'delivered') {
          final orderData = doc.data()!;

          await FirebaseFirestore.instance
              .collection('delivered_orders')
              .doc(activeOrderId)
              .set(orderData);

          await FirebaseFirestore.instance
              .collection('orders')
              .doc(activeOrderId)
              .delete();

          final customerId = prefs.getString('customerId') ?? '';
          if (customerId.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('customers')
                .doc(customerId)
                .update({'آخر طلب': orderData['createdAt'] ?? ''});
          }

          await prefs.remove('activeOrderId');
          await prefs.remove('activeOrderAddress');
          await prefs.remove('activeOrderTotal');
          await prefs.remove('activeOrderItems');
          await prefs.setBool('cartCleared', true);
          await prefs.setBool('quantitiesCleared', true);
        } else if (status.isNotEmpty && status != 'delivered') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => OrderTrackingPage(
                cartItems: const [],
                total: activeOrderTotal,
                address: activeOrderAddress,
                orderId: activeOrderId,
              ),
            ),
            (route) => false,
          );
          return;
        } else {
          await prefs.remove('activeOrderId');
          await prefs.remove('activeOrderAddress');
          await prefs.remove('activeOrderTotal');
          await prefs.remove('activeOrderItems');
          await prefs.setBool('cartCleared', true);
        }
      } catch (e) {
        await prefs.remove('activeOrderId');
        await prefs.remove('activeOrderAddress');
        await prefs.remove('activeOrderTotal');
      }
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(name: name, email: address),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation:
            Listenable.merge([_bgController, _logoController, _textController]),
        builder: (context, child) {
          return Stack(
            children: [
              Center(
                child: Transform.scale(
                  scale: _bgScale.value * 3,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🛒', style: TextStyle(fontSize: 60)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: const Column(
                          children: [
                            Text(
                              'ROMANA',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 6,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'خضروات وفواكه طازجة',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 100,
                right: 40,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: const Text('🍅', style: TextStyle(fontSize: 30)),
                ),
              ),
              Positioned(
                top: 150,
                left: 30,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: const Text('🥦', style: TextStyle(fontSize: 25)),
                ),
              ),
              Positioned(
                bottom: 150,
                right: 30,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: const Text('🍊', style: TextStyle(fontSize: 28)),
                ),
              ),
              Positioned(
                bottom: 120,
                left: 40,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: const Text('🍇', style: TextStyle(fontSize: 26)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
