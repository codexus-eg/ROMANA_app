import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class OrderTrackingPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double total;
  final String address;
  final String orderId;

  const OrderTrackingPage({
    super.key,
    required this.cartItems,
    required this.total,
    required this.address,
    required this.orderId,
  });

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage>
    with WidgetsBindingObserver {
  bool autoMoved = false;
  Stream<DocumentSnapshot>? _orderStream;
  String _lastStatus = '';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final List<Map<String, dynamic>> steps = const [
    {
      'title': 'تم استلام طلبك',
      'subtitle': 'جاري مراجعة طلبك',
      'icon': Icons.check_circle,
      'color': Colors.green,
      'status': 'pending',
    },
    {
      'title': 'جاري تجهيز طلبك',
      'subtitle': 'يتم تجهيز طلبك',
      'icon': Icons.restaurant,
      'color': Colors.orange,
      'status': 'approved',
    },
    {
      'title': 'جاري توصيل طلبك',
      'subtitle': 'المندوب في الطريق إليك',
      'icon': Icons.delivery_dining,
      'color': Colors.blue,
      'status': 'in_progress',
    },
    {
      'title': 'تم توصيل طلبك! 🎉',
      'subtitle': 'شكراً لطلبك معنا',
      'icon': Icons.done_all,
      'color': Colors.green,
      'status': 'delivered',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _initStream();
    _checkDelivered();
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    // تم التعديل إلى settings بدلاً من initializationSettings
    await _notifications.initialize(settings: initSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'romana_channel', // id
      'ROMANA', // name
      channelDescription: 'إشعارات تتبع الطلب',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'تم استلام طلبك ✅';
      case 'approved':
        return 'جاري تجهيز طلبك 👨‍🍳';
      case 'in_progress':
        return 'طلبك في الطريق إليك 🚚';
      case 'delivered':
        return 'تم توصيل طلبك! 🎉';
      default:
        return 'تحديث الطلب';
    }
  }

  String _getStatusBody(String status) {
    switch (status) {
      case 'pending':
        return 'تم استلام طلبك وجاري مراجعته';
      case 'approved':
        return 'طلبك قيد التجهيز الآن';
      case 'in_progress':
        return 'المندوب في الطريق إليك';
      case 'delivered':
        return 'وصل طلبك! شكراً لك 😊';
      default:
        return '';
    }
  }

  void _initStream() {
    _orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();
  }

  Future<void> _checkDelivered() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (doc.exists) {
        final status = doc.data()?['status'] ?? '';
        if (status == 'delivered' && !autoMoved) {
          await moveToDelivered(doc.data()!);
          // تم التعديل إلى !mounted الخاصة بالـ State
          if (!mounted) return;
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint('Error checking delivered: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() => _initStream());
        _checkDelivered();
      }
    }
  }

  int getStepIndex(String status) {
    switch (status) {
      case 'pending':
        return 0;
      case 'approved':
        return 1;
      case 'in_progress':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  int fixPrice(dynamic value) {
    if (value == null) return 0;
    final raw = (value as num).toDouble();
    return raw < 1 ? (raw * 100).toInt() : raw.toInt();
  }

  String getItemName(Map<String, dynamic> item) =>
      item['اسم'] ?? item['name'] ?? '';
  String getItemUnit(Map<String, dynamic> item) =>
      item['مقياس'] ?? item['وحدة'] ?? item['unit'] ?? '';
  String getItemImage(Map<String, dynamic> item) =>
      item['صورة'] ?? item['image'] ?? '';
  dynamic getItemPrice(Map<String, dynamic> item) =>
      item['سعر الكيلو'] ?? item['سعر'] ?? item['price'] ?? 0;
  dynamic getItemQty(Map<String, dynamic> item) =>
      item['كمية'] ?? item['qty'] ?? 0;

  Future<void> goHome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cartCleared', true);
    await prefs.remove('activeOrderId');
    await prefs.remove('activeOrderAddress');
    await prefs.remove('activeOrderTotal');
    await prefs.remove('activeOrderItems');
    // تم التعديل إلى !mounted الخاصة بالـ State
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> moveToDelivered(Map<String, dynamic> orderData) async {
    if (autoMoved) return;
    autoMoved = true;

    try {
      await FirebaseFirestore.instance
          .collection('delivered_orders')
          .doc(widget.orderId)
          .set(orderData);

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .delete();

      final prefs = await SharedPreferences.getInstance();
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
    } catch (e) {
      autoMoved = false;
      debugPrint('Error moving to delivered: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        await goHome();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.red,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: goHome,
          ),
          title: const Text('تتبع طلبك 📦',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          key: ValueKey(widget.orderId),
          stream: _orderStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.red));
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 80, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text('تم توصيل طلبك! 🎉',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: goHome,
                      icon: const Icon(Icons.home, color: Colors.white),
                      label: const Text('الرئيسية',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final currentStep = getStepIndex(status);
            final step = steps[currentStep];

            if (_lastStatus != status && _lastStatus.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showNotification(
                    _getStatusTitle(status), _getStatusBody(status));
              });
            }
            _lastStatus = status;

            if (status == 'delivered' && !autoMoved) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await moveToDelivered(data);
                // تم التعديل إلى !mounted الخاصة بالـ State
                if (!mounted) return;
                Navigator.popUntil(context, (route) => route.isFirst);
              });
            }

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(step['icon'] as IconData,
                          size: 60, color: step['color'] as Color),
                      const SizedBox(height: 12),
                      Text(step['title'] as String,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 6),
                      Text(step['subtitle'] as String,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: List.generate(steps.length, (index) {
                      return Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: index <= currentStep
                                  ? Colors.red
                                  : Colors.grey.shade300,
                              child: Icon(steps[index]['icon'] as IconData,
                                  size: 16, color: Colors.white),
                            ),
                            if (index < steps.length - 1)
                              Expanded(
                                child: Container(
                                  height: 3,
                                  color: index < currentStep
                                      ? Colors.red
                                      : Colors.grey.shade300,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('تفاصيل الطلب',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...widget.cartItems.map((item) {
                        final price = fixPrice(getItemPrice(item));
                        final qty = (getItemQty(item) as num).toDouble();
                        final itemTotal = price * qty;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                getItemImage(item),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                    Icons.image,
                                    size: 40,
                                    color: Colors.grey),
                              ),
                            ),
                            title: Text(getItemName(item),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '\u200E${qty % 1 == 0 ? qty.toInt() : qty} ${getItemUnit(item)}'),
                            trailing: Text(
                              '\u200E${itemTotal % 1 == 0 ? itemTotal.toInt() : itemTotal.toStringAsFixed(1)} ريال',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('العنوان:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(widget.address,
                                      style:
                                          const TextStyle(color: Colors.grey),
                                      textAlign: TextAlign.left),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الإجمالي:',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                Text(
                                  '\u200E${widget.total % 1 == 0 ? widget.total.toInt() : widget.total.toStringAsFixed(1)} ريال',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
