import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_tracking_page.dart';

class InvoicePage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double total;
  final String address;
  final String addressName;
  final String deliveryFrom;
  final String deliveryTo;

  const InvoicePage({
    super.key,
    required this.cartItems,
    required this.total,
    required this.address,
    required this.addressName,
    required this.deliveryFrom,
    required this.deliveryTo,
  });

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  bool isOrdering = false;
  final double deliveryFee = 10.0;
  double walletBalance = 0.0;
  String customerId = '';
  bool isLoadingWallet = true;
  int orderNumber = 0;

  double get grandTotal => widget.total + deliveryFee;
  double get afterWallet =>
      (grandTotal - walletBalance).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    loadWallet();
  }

  Future<void> loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    customerId = prefs.getString('customerId') ?? '';

    if (customerId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final walletRaw = data['محفظة'] ?? data['wallet'] ?? '0';
        setState(() {
          walletBalance = double.tryParse(walletRaw.toString()) ?? 0.0;
          isLoadingWallet = false;
        });
      } else {
        setState(() => isLoadingWallet = false);
      }
    } else {
      setState(() => isLoadingWallet = false);
    }
  }

  int fixPrice(dynamic value) {
    if (value == null) return 0;
    final raw = (value as num).toDouble();
    return raw < 1 ? (raw * 100).toInt() : raw.toInt();
  }

  String formatNum(double val) {
    return '\u200E${val % 1 == 0 ? val.toInt() : val.toStringAsFixed(1)}';
  }

  Future<void> confirmOrder() async {
    setState(() => isOrdering = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('name') ?? 'عميل';

      // توليد رقم الطلب التسلسلي
      int newOrderNumber = 1;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final counterRef =
            FirebaseFirestore.instance.collection('counters').doc('orders');
        final counterDoc = await transaction.get(counterRef);

        if (counterDoc.exists) {
          newOrderNumber = (counterDoc.data()?['count'] ?? 0) + 1;
        } else {
          newOrderNumber = 1;
        }

        transaction.set(counterRef, {'count': newOrderNumber});
      });

      setState(() => orderNumber = newOrderNumber);

      // الـ Document ID هو الرقم التسلسلي نفسه
      final docRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(newOrderNumber.toString());

      await docRef.set({
        'orderNumber': newOrderNumber,
        'status': 'pending',
        'total': afterWallet,
        'itemsTotal': widget.total,
        'deliveryFee': deliveryFee,
        'walletUsed': walletBalance > 0 ? walletBalance : 0,
        'address': widget.address,
        'addressName': widget.addressName,
        'customerName': name,
        'createdAt': DateTime.now().toString(),
        'deliveryFrom': widget.deliveryFrom,
        'deliveryTo': widget.deliveryTo,
        'items': widget.cartItems.map((item) {
          final qty = (item['qty'] as num).toDouble();
          final pricePerUnit = fixPrice(item['price']);
          final totalPrice = pricePerUnit * qty;
          return {
            'اسم': item['name'],
            'سعر الكيلو': pricePerUnit,
            'سعر الاجمالي': totalPrice,
            'كمية': qty,
            'مقياس': item['unit'],
            'صورة': item['image'],
            'name': item['name'],
            'price': pricePerUnit,
            'total_price': totalPrice,
            'qty': qty,
            'unit': item['unit'],
            'image': item['image'],
          };
        }).toList(),
      });

      if (customerId.isNotEmpty) {
        final newWallet =
            (walletBalance - grandTotal).clamp(0.0, double.infinity);
        await FirebaseFirestore.instance
            .collection('customers')
            .doc(customerId)
            .update({
          'آخر طلب': DateTime.now().toString(),
          'محفظة': newWallet.toStringAsFixed(1),
        });
      }

      await prefs.setString('activeOrderId', newOrderNumber.toString());
      await prefs.setString('activeOrderAddress', widget.address);
      await prefs.setDouble('activeOrderTotal', afterWallet);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderTrackingPage(
            cartItems: widget.cartItems,
            total: afterWallet,
            address: widget.address,
            orderId: newOrderNumber.toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل إرسال الطلب! حاول تاني'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isOrdering = false);
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
          title: const Text('الفاتورة 🧾',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoadingWallet
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.receipt_long,
                                    size: 50, color: Colors.red),
                                const SizedBox(height: 8),
                                const Text('فاتورة طلبك',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold)),
                                if (orderNumber > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'طلب رقم #$orderNumber',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.red, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.addressName,
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.address,
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time,
                                    color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'وقت التوصيل: ${widget.deliveryFrom} - ${widget.deliveryTo}',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('المنتجات',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...widget.cartItems.map((item) {
                            final qty = (item['qty'] as num).toDouble();
                            final price = fixPrice(item['price']);
                            final itemTotal = qty * price;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item['image'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => const Icon(
                                          Icons.image,
                                          size: 40,
                                          color: Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                        Text(
                                          '\u200E${qty % 1 == 0 ? qty.toInt() : qty} ${item['unit']} × $price ريال',
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${formatNum(itemTotal)} ريال',
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          const Divider(thickness: 2),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('إجمالي المنتجات:',
                                  style: TextStyle(fontSize: 16)),
                              Text('${formatNum(widget.total)} ريال',
                                  style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('رسوم التوصيل:',
                                  style: TextStyle(fontSize: 16)),
                              Text('\u200E${deliveryFee.toInt()} ريال',
                                  style: const TextStyle(
                                      fontSize: 16, color: Colors.orange)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('الإجمالي:',
                                  style: TextStyle(fontSize: 16)),
                              Text('${formatNum(grandTotal)} ريال',
                                  style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                          if (walletBalance > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(children: [
                                        Icon(Icons.account_balance_wallet,
                                            color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('رصيد المحفظة:',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold)),
                                      ]),
                                      Text(
                                        '${formatNum(walletBalance)} ريال',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '\u200E${formatNum(grandTotal)} - ${formatNum(walletBalance)} = ${formatNum(afterWallet)} ريال',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          const Divider(thickness: 2),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('المبلغ المطلوب:',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                '${formatNum(afterWallet)} ريال',
                                style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          if (walletBalance > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'تم خصم ${formatNum(walletBalance)} ريال من محفظتك 🎉',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isOrdering ? null : confirmOrder,
                        child: isOrdering
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('تأكيد الطلب ✅',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
