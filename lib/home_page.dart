import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:romana/myOrders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'cart_page.dart';
import 'order_tracking_page.dart';
import 'login_page.dart';
import 'addresses_page.dart';
import 'account_page.dart';

class HomePage extends StatefulWidget {
  final String name;
  final String email;
  const HomePage({super.key, required this.name, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<Map<String, dynamic>> cart = [];
  String selectedCategory = 'الكل';
  Map<String, double> quantities = {};
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> ads = [];
  bool isLoading = true;
  String customerName = '';
  String customerId = '';
  String searchQuery = '';
  bool isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadCustomerData();
    loadProducts();
    loadAds();
    checkCartCleared();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkCartCleared();
    }
  }

  Future<void> loadCustomerData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? '';
    final id = prefs.getString('customerId') ?? '';
    if (mounted) {
      setState(() {
        customerName = name.isNotEmpty ? name : widget.name;
        customerId = id;
      });
    }
  }

  Future<void> loadAds() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('ads')
        .where('نشط', isEqualTo: true)
        .get();
    if (mounted) {
      setState(() {
        ads = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    }
  }

  Future<void> checkCartCleared() async {
    final prefs = await SharedPreferences.getInstance();
    final cartCleared = prefs.getBool('cartCleared') ?? false;
    final quantitiesCleared = prefs.getBool('quantitiesCleared') ?? false;

    if (cartCleared) {
      if (mounted) setState(() => cart = []);
      await prefs.remove('cartCleared');
    }

    if (quantitiesCleared) {
      if (mounted) setState(() => quantities = {});
      await prefs.remove('quantitiesCleared');
    }
  }

  Future<void> loadProducts() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('products').get();
    if (mounted) {
      setState(() {
        allProducts = snapshot.docs.map((doc) {
          final data = doc.data();
          final rawPrice =
              ((data['سعر'] ?? data['price'] ?? 0) as num).toDouble();
          final rawOldPrice =
              ((data['سعر اصلي'] ?? data['oldPrice'] ?? 0) as num).toDouble();
          return {
            'id': doc.id,
            'name': data['اسم'] ?? data['name'] ?? '',
            'price': rawPrice < 1 ? (rawPrice * 100).toInt() : rawPrice.toInt(),
            'image': data['صورة'] ?? data['image'] ?? '',
            'category': data['قسم'] ?? data['category'] ?? '',
            'unit': data['مقياس'] ?? data['unit'] ?? 'كجم',
            'discount': data['تخفيض'] == true || data['discount'] == true,
            'oldPrice': rawOldPrice < 1
                ? (rawOldPrice * 100).toInt()
                : rawOldPrice.toInt(),
            'description': data['وصف'] ?? data['description'] ?? '',
            'available': data['متوفر'] ?? data['available'] ?? true,
          };
        }).toList();
        isLoading = false;
      });
    }
  }

  void onAdTap(Map<String, dynamic> ad) async {
    final type = ad['نوع'] ?? '';

    if (type == 'منتج') {
      final productId = ad['معرف_المنتج'] ?? '';
      if (productId.isNotEmpty) {
        final product = allProducts.firstWhere(
          (p) => p['id'] == productId,
          orElse: () => {},
        );
        if (product.isNotEmpty) {
          showProductDetails(product, false);
        }
      }
    } else if (type == 'تطبيق') {
      final packageName = ad['باكج_التطبيق'] ?? '';
      final storeUrl = ad['رابط_المتجر'] ?? '';

      if (packageName.isNotEmpty) {
        // أول بيجرب يفتح التطبيق لو موجود
        try {
          final appUri = Uri.parse('android-app://$packageName');
          if (await canLaunchUrl(appUri)) {
            await launchUrl(appUri);
            return;
          }
        } catch (e) {}

        // لو مش موجود يروح Play Store
        try {
          final marketUri = Uri.parse('market://details?id=$packageName');
          if (await canLaunchUrl(marketUri)) {
            await launchUrl(marketUri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (e) {}
      }

      // آخر حل يفتح الرابط عادي
      if (storeUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(storeUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {}
      }
    }
  }

  List<Map<String, dynamic>> get filteredProducts {
    List<Map<String, dynamic>> products;
    if (searchQuery.isNotEmpty) {
      products = allProducts
          .where((p) => p['name']
              .toString()
              .toLowerCase()
              .contains(searchQuery.toLowerCase()))
          .toList();
    } else if (selectedCategory == 'الكل') {
      products = allProducts;
    } else if (selectedCategory == 'عروض') {
      products = allProducts.where((p) => p['discount'] == true).toList();
    } else {
      products =
          allProducts.where((p) => p['category'] == selectedCategory).toList();
    }
    return products;
  }

  double getQty(String name) => quantities[name] ?? 0.0;

  double getStep(String unit) {
    final wholeUnits = [
      'علبة',
      'عبوة',
      'حزمة',
      'قطعة',
      'كيس',
      'علبه',
      'عبوه',
      'حزمه',
      'قطعه',
      'خيشة',
      'حبه',
      'حبة',
    ];
    return wholeUnits.contains(unit) ? 1.0 : 0.5;
  }

  String formatQty(double qty, String unit) {
    final wholeUnits = [
      'علبة',
      'عبوة',
      'حزمة',
      'قطعة',
      'كيس',
      'علبه',
      'عبوه',
      'حزمه',
      'قطعه',
      'خيشة',
      'حبه',
      'حبة',
    ];
    if (wholeUnits.contains(unit)) return '${qty.toInt()} $unit';
    return '${qty.toStringAsFixed(1)} $unit';
  }

  void addToCart(Map<String, dynamic> product, bool hasActiveOrder) {
    if (hasActiveOrder) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لديك طلب جاري! انتظر حتى يصلك'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ));
      return;
    }
    final qty = getQty(product['name']);
    if (qty == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ اختار الكمية الأول!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ));
      return;
    }
    setState(() {
      final index = cart.indexWhere((p) => p['name'] == product['name']);
      if (index >= 0) {
        cart[index]['qty'] = (cart[index]['qty'] as num).toDouble() + qty;
      } else {
        cart.add({...product, 'qty': qty});
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text('✅ ${formatQty(qty, product['unit'])} - ${product['name']}'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 1),
    ));
  }

  void showProductDetails(Map<String, dynamic> product, bool hasActiveOrder) {
    final isAvailable = product['available'] == true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        child: Image.network(
                          product['image'],
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            height: 250,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image,
                                size: 80, color: Colors.grey),
                          ),
                        ),
                      ),
                      if (!isAvailable)
                        Container(
                          width: double.infinity,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24)),
                          ),
                          child: const Center(
                            child: Text('غير متاح حالياً',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(product['name'],
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            if (product['discount'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Text('خصم!',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (product['discount'] == true)
                          Text(
                              '${product['unit']} : ${product['oldPrice']} ريال',
                              style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 16)),
                        Text('${product['unit']} : ${product['price']} ريال',
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 20)),
                        const SizedBox(height: 16),
                        if (product['description'].toString().isNotEmpty) ...[
                          const Text('الوصف',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(product['description'],
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                  height: 1.5)),
                          const SizedBox(height: 20),
                        ],
                        if (!isAvailable)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Row(children: [
                              Icon(Icons.block, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('عذراً، هذا المنتج غير متاح الآن',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        if (isAvailable && hasActiveOrder)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: const Row(children: [
                              Icon(Icons.info, color: Colors.orange),
                              SizedBox(width: 8),
                              Expanded(
                                  child: Text('لديك طلب جاري! انتظر حتى يصلك',
                                      style: TextStyle(color: Colors.orange))),
                            ]),
                          ),
                        if (isAvailable && !hasActiveOrder) ...[
                          const Text('الكمية',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          StatefulBuilder(
                            builder: (context, setModalState) {
                              final qty = getQty(product['name']);
                              final step = getStep(product['unit']);
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove_circle,
                                        color:
                                            qty > 0 ? Colors.red : Colors.grey,
                                        size: 32),
                                    onPressed: () {
                                      if (qty > 0) {
                                        setState(() {
                                          quantities[product['name']] =
                                              qty - step;
                                          if (quantities[product['name']]! <
                                              0) {
                                            quantities[product['name']] = 0;
                                          }
                                        });
                                        setModalState(() {});
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 16),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(formatQty(qty, product['unit']),
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle,
                                        color: Colors.green, size: 32),
                                    onPressed: () {
                                      setState(() =>
                                          quantities[product['name']] =
                                              qty + step);
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                addToCart(product, hasActiveOrder);
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.add_shopping_cart,
                                  color: Colors.white),
                              label: const Text('أضف للسلة',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRefreshIndicator(
    BuildContext context,
    Widget child,
    IndicatorController controller,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Stack(
          children: [
            if (controller.value > 0)
              Positioned(
                top: (controller.value * 80) - 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // كرات بتلف حول حرف R
                        ...List.generate(6, (index) {
                          final angle = (index / 6 * 2 * pi) +
                              (controller.value * 2 * pi);
                          final x = 22 * cos(angle);
                          final y = 22 * sin(angle);
                          return Transform.translate(
                            offset: Offset(x, y),
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: [
                                  Colors.red,
                                  Colors.orange,
                                  Colors.green,
                                  Colors.blue,
                                  Colors.purple,
                                  Colors.red.shade300,
                                ][index],
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }),
                        // حرف R
                        const Text(
                          'R',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, controller.value * 80),
              child: child,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = customerName.isNotEmpty ? customerName : widget.name;

    if (displayName.isEmpty) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.red)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerName', isEqualTo: displayName)
          .where('status',
              whereIn: ['pending', 'approved', 'in_progress']).snapshots(),
      builder: (context, snapshot) {
        final hasActiveOrder =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        String activeOrderId = '';
        String activeOrderAddress = '';
        double activeOrderTotal = 0.0;

        if (hasActiveOrder) {
          final doc = snapshot.data!.docs.first;
          activeOrderId = doc.id;
          activeOrderAddress = doc['address'] ?? '';
          final rawTotal = (doc['total'] as num).toDouble();
          activeOrderTotal = rawTotal < 1 ? rawTotal * 100 : rawTotal;
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.red,
            title: isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن منتج...',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  )
                : const Text('ROMANA 🛒',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: Icon(isSearching ? Icons.close : Icons.search,
                    color: Colors.white),
                onPressed: () {
                  setState(() {
                    isSearching = !isSearching;
                    if (!isSearching) {
                      searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.delivery_dining,
                    color: hasActiveOrder ? Colors.white : Colors.white38),
                onPressed: hasActiveOrder
                    ? () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderTrackingPage(
                                orderId: activeOrderId,
                                address: activeOrderAddress,
                                total: activeOrderTotal,
                                cartItems: const [],
                              ),
                            ));
                        checkCartCleared();
                      }
                    : () {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('لا يوجد طلب حاليا!'),
                          backgroundColor: Colors.grey,
                          duration: Duration(seconds: 1),
                        ));
                      },
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: hasActiveOrder
                        ? () {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                              content: Text('لديك طلب جاري! انتظر حتى يصلك'),
                              backgroundColor: Colors.orange,
                            ));
                          }
                        : () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CartPage(
                                    cart: cart,
                                    onCartUpdated: (updatedCart) =>
                                        setState(() => cart = updatedCart),
                                  ),
                                ));
                          },
                  ),
                  if (cart.isNotEmpty && !hasActiveOrder)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.yellow,
                        child: Text('${cart.length}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              PopupMenuButton(
                icon: const Icon(Icons.account_circle,
                    color: Colors.white, size: 30),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(children: [
                      const Icon(Icons.person, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(widget.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                    onTap: () => Future.delayed(
                        Duration.zero,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const AccountPage()))),
                  ),
                  PopupMenuItem(
                    child: customerId.isEmpty
                        ? const Row(children: [
                            Icon(Icons.account_balance_wallet,
                                color: Colors.red),
                            SizedBox(width: 8),
                            Text('المحفظة: 0 ريال'),
                          ])
                        : StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('customers')
                                .doc(customerId)
                                .snapshots(),
                            builder: (context, walletSnapshot) {
                              double wallet = 0.0;
                              if (walletSnapshot.hasData &&
                                  walletSnapshot.data!.exists) {
                                final data = walletSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                wallet = double.tryParse(
                                        (data['محفظة'] ?? data['wallet'] ?? '0')
                                            .toString()) ??
                                    0.0;
                              }
                              return Row(children: [
                                const Icon(Icons.account_balance_wallet,
                                    color: Colors.red),
                                const SizedBox(width: 8),
                                Text(
                                  'المحفظة: ${wallet % 1 == 0 ? wallet.toInt() : wallet.toStringAsFixed(1)} ريال',
                                ),
                              ]);
                            },
                          ),
                  ),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.shopping_bag, color: Colors.red),
                      SizedBox(width: 8),
                      Text('طلباتي')
                    ]),
                    onTap: () => Future.delayed(
                        Duration.zero,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MyOrdersPage()))),
                  ),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.location_on, color: Colors.red),
                      SizedBox(width: 8),
                      Text('العناوين')
                    ]),
                    onTap: () => Future.delayed(
                        Duration.zero,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AddressesPage()))),
                  ),
                  PopupMenuItem(
                    child: const Row(children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('تسجيل خروج')
                    ]),
                    onTap: () => Future.delayed(Duration.zero, () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                          (route) => false);
                    }),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (hasActiveOrder)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: Colors.orange.shade100,
                  child: const Row(children: [
                    Icon(Icons.info, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('لديك طلب جاري! يمكنك التصفح فقط',
                        style: TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold)),
                  ]),
                ),

              // الإعلانات
              if (ads.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, color: Colors.red, size: 20),
                      SizedBox(width: 6),
                      Text('عروض خاصة',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red)),
                    ],
                  ),
                ),
                CarouselSlider(
                  options: CarouselOptions(
                    height: 150,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 4),
                    enlargeCenterPage: false,
                    viewportFraction: 1.0,
                    padEnds: false,
                  ),
                  items: ads.map((ad) {
                    return GestureDetector(
                      onTap: () => onAdTap(ad),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ad['صورة'] ?? '',
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.red.shade100,
                              child: const Center(
                                child: Icon(Icons.image,
                                    size: 50, color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              if (!isSearching)
                Container(
                  height: 50,
                  color: Colors.red.shade50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: ['الكل', 'فواكه', 'خضروات', 'عروض'].map((cat) {
                      final isSelected = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => selectedCategory = cat),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Center(
                            child: Text(cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.red,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.red))
                    : filteredProducts.isEmpty
                        ? Center(
                            child: Text(searchQuery.isNotEmpty
                                ? 'لا يوجد منتج بهذا الاسم'
                                : 'لا يوجد منتجات'))
                        : CustomRefreshIndicator(
                            onRefresh: () async {
                              await loadProducts();
                              await loadAds();
                            },
                            builder: _buildRefreshIndicator,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.55,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final qty = getQty(product['name']);
                                final step = getStep(product['unit']);
                                final isAvailable =
                                    product['available'] == true;
                                return Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (product['discount'] == true)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                            child: const Text('خصم!',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11)),
                                          ),
                                        GestureDetector(
                                          onTap: () => showProductDetails(
                                              product, hasActiveOrder),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  product['image'],
                                                  height: 70,
                                                  width: 70,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (c, e, s) =>
                                                      const Icon(Icons.image,
                                                          size: 60,
                                                          color: Colors.grey),
                                                ),
                                              ),
                                              if (!isAvailable)
                                                Container(
                                                  height: 70,
                                                  width: 70,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: const Center(
                                                      child: Icon(Icons.block,
                                                          color: Colors.white,
                                                          size: 30)),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(product['name'],
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold)),
                                        if (product['discount'] == true)
                                          Text(
                                              '${product['unit']} - ${product['oldPrice']} ريال',
                                              style: const TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  color: Colors.grey,
                                                  fontSize: 11)),
                                        Text(
                                            '${product['unit']} : ${product['price']} ريال',
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        if (!isAvailable)
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Center(
                                                child: Text('غير متاح حالياً',
                                                    style: TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold))),
                                          ),
                                        if (isAvailable) ...[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: Icon(Icons.remove_circle,
                                                    color: !hasActiveOrder &&
                                                            qty > 0
                                                        ? Colors.red
                                                        : Colors.grey,
                                                    size: 20),
                                                onPressed: hasActiveOrder
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          if (qty > 0) {
                                                            quantities[product[
                                                                    'name']] =
                                                                qty - step;
                                                            if (quantities[product[
                                                                    'name']]! <
                                                                0) {
                                                              quantities[product[
                                                                  'name']] = 0;
                                                            }
                                                          }
                                                        });
                                                      },
                                              ),
                                              const SizedBox(width: 4),
                                              Directionality(
                                                textDirection:
                                                    TextDirection.ltr,
                                                child: Text(
                                                    formatQty(
                                                        qty, product['unit']),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12)),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                                icon: Icon(Icons.add_circle,
                                                    color: hasActiveOrder
                                                        ? Colors.grey
                                                        : Colors.green,
                                                    size: 20),
                                                onPressed: hasActiveOrder
                                                    ? null
                                                    : () {
                                                        setState(() =>
                                                            quantities[product[
                                                                    'name']] =
                                                                qty + step);
                                                      },
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: hasActiveOrder
                                                    ? Colors.grey
                                                    : qty > 0
                                                        ? Colors.red
                                                        : Colors.grey,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                              ),
                                              onPressed: hasActiveOrder
                                                  ? null
                                                  : () => addToCart(
                                                      product, hasActiveOrder),
                                              icon: const Icon(
                                                  Icons.add_shopping_cart,
                                                  color: Colors.white,
                                                  size: 14),
                                              label: const Text('أضف',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
