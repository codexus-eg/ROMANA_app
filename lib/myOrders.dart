import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyOrdersPage extends StatefulWidget {
  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  String customerName = '';
  bool isLoading = true;
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> deliveredOrders = [];

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    customerName = prefs.getString('name') ?? '';

    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('customerName', isEqualTo: customerName)
        .get();

    final deliveredSnapshot = await FirebaseFirestore.instance
        .collection('delivered_orders')
        .where('customerName', isEqualTo: customerName)
        .get();

    setState(() {
      orders = ordersSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      deliveredOrders = deliveredSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      isLoading = false;
    });
  }

  // تصحيح الأرقام - لو الرقم في Firebase صح ما نغيرهوش
  double fixNumber(dynamic value) {
    if (value == null) return 0.0;
    return (value as num).toDouble();
  }

  int fixPrice(dynamic value) {
    if (value == null) return 0;
    return (value as num).toInt();
  }

  String getItemName(Map<String, dynamic> item) =>
      item['اسم'] ?? item['name'] ?? '';
  String getItemUnit(Map<String, dynamic> item) =>
      item['مقياس'] ?? item['وحدة'] ?? item['unit'] ?? '';
  String getItemImage(Map<String, dynamic> item) =>
      item['صورة'] ?? item['image'] ?? '';
  dynamic getItemPrice(Map<String, dynamic> item) =>
      item['سعر'] ?? item['price'] ?? 0;
  dynamic getItemQty(Map<String, dynamic> item) =>
      item['كمية'] ?? item['qty'] ?? 0;

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'تم استلام الطلب';
      case 'approved':
        return 'جاري التجهيز';
      case 'in_progress':
        return 'جاري التوصيل';
      case 'delivered':
        return 'تم التوصيل';
      default:
        return 'غير معروف';
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget buildOrderCard(Map<String, dynamic> order, bool isDelivered) {
    final items = List<Map<String, dynamic>>.from(
        (order['items'] as List).map((e) => Map<String, dynamic>.from(e)));
    final status = order['status'] ?? 'pending';
    final total = fixNumber(order['total']);
    final address = order['address'] ?? '';
    final createdAt = order['createdAt'] ?? '';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(16),
        childrenPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isDelivered ? Colors.green : Colors.red,
          child: Icon(
            isDelivered ? Icons.done_all : Icons.shopping_bag,
            color: Colors.white,
          ),
        ),
        title: Text(
          'طلب - ${createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: getStatusColor(status),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getStatusText(status),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'الإجمالي: ${total % 1 == 0 ? total.toInt() : total.toStringAsFixed(1)} ريال',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(),
              Text('المنتجات:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              ...items.map((item) {
                final price = fixPrice(getItemPrice(item));
                final qty = (getItemQty(item) as num).toDouble();
                final itemTotal = price * qty;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          getItemImage(item),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              Icon(Icons.image, size: 40, color: Colors.grey),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(getItemName(item),
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${qty % 1 == 0 ? qty.toInt() : qty} ${getItemUnit(item)}',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              '${getItemUnit(item)} : $price ريال',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${itemTotal % 1 == 0 ? itemTotal.toInt() : itemTotal.toStringAsFixed(1)} ريال',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('العنوان:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(address, style: TextStyle(color: Colors.grey)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الإجمالي:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    '${total % 1 == 0 ? total.toInt() : total.toStringAsFixed(1)} ريال',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: Text('طلباتي 📦',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.red))
          : orders.isEmpty && deliveredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('لا يوجد طلبات بعد',
                          style: TextStyle(fontSize: 20, color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadOrders,
                  color: Colors.red,
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      if (orders.isNotEmpty) ...[
                        Text('الطلبات الجارية',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        ...orders.map((order) => buildOrderCard(order, false)),
                        SizedBox(height: 16),
                      ],
                      if (deliveredOrders.isNotEmpty) ...[
                        Text('الطلبات المكتملة',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        ...deliveredOrders
                            .map((order) => buildOrderCard(order, true)),
                      ],
                    ],
                  ),
                ),
    );
  }
}
