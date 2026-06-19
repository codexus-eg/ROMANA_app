import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'invoice_page.dart';

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final Function(List<Map<String, dynamic>>) onCartUpdated;
  CartPage({required this.cart, required this.onCartUpdated});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late List<Map<String, dynamic>> cartItems;
  bool isOrdering = false;
  int? selectedFromHour;
  int? selectedToHour;
  List<Map<String, dynamic>> addresses = [];
  String? selectedAddressId;
  String selectedAddressText = '';
  bool isLoadingAddresses = true;

  @override
  void initState() {
    super.initState();
    cartItems = List.from(widget.cart);
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final customerId = prefs.getString('customerId') ?? '';
    if (customerId.isNotEmpty) {
      final snapshot = await FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .collection('addresses')
          .get();
      setState(() {
        addresses = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        isLoadingAddresses = false;
      });
    } else {
      setState(() => isLoadingAddresses = false);
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
      item['مقياس'] ?? item['unit'] ?? '';
  String getItemImage(Map<String, dynamic> item) =>
      item['صورة'] ?? item['image'] ?? '';
  dynamic getItemPrice(Map<String, dynamic> item) =>
      item['سعر'] ?? item['price'] ?? 0;
  dynamic getItemQty(Map<String, dynamic> item) =>
      item['كمية'] ?? item['qty'] ?? 0;

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
      'كيسه',
      'خيشة',
      'حبة',
    ];
    return wholeUnits.contains(unit) ? 1.0 : 0.5;
  }

  double get total => cartItems.fold(
      0.0,
      (sum, item) =>
          sum +
          fixPrice(getItemPrice(item)) * (getItemQty(item) as num).toDouble());

  void updateCart() {
    widget.onCartUpdated(cartItems);
  }

  List<int> getAvailableFromHours() {
    final now = DateTime.now();
    final minHour = now.hour + 1;
    return List.generate(24 - minHour, (i) => minHour + i)
        .where((h) => h < 24)
        .toList();
  }

  List<int> getAvailableToHours() {
    if (selectedFromHour == null) return [];
    return List.generate(
            24 - selectedFromHour! - 1, (i) => selectedFromHour! + 1 + i)
        .where((h) => h < 24)
        .toList();
  }

  String formatHour(int hour) {
    if (hour == 0) return '\u200E12:00 ص';
    if (hour < 12) return '\u200E$hour:00 ص';
    if (hour == 12) return '\u200E12:00 م';
    return '\u200E${hour - 12}:00 م';
  }

  String get deliveryFromText =>
      selectedFromHour != null ? formatHour(selectedFromHour!) : '';
  String get deliveryToText =>
      selectedToHour != null ? formatHour(selectedToHour!) : '';

  bool get isDeliverySelected =>
      selectedFromHour != null && selectedToHour != null;
  bool get isAddressSelected => selectedAddressId != null;
  bool get canOrder =>
      isDeliverySelected && isAddressSelected && cartItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final availableFrom = getAvailableFromHours();
    final availableTo = getAvailableToHours();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: Text('سلة المشتريات 🛒',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: cartItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🛒', style: TextStyle(fontSize: 80)),
                    SizedBox(height: 16),
                    Text('السلة فاضية!',
                        style: TextStyle(fontSize: 22, color: Colors.grey)),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        final price = fixPrice(getItemPrice(item));
                        final qty = (getItemQty(item) as num).toDouble();
                        final unit = getItemUnit(item);
                        final step = getStep(unit);
                        final itemTotal = price * qty;

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          margin: EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    getItemImage(item),
                                    height: 60,
                                    width: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Icon(Icons.image,
                                        size: 50, color: Colors.grey),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(getItemName(item),
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      RichText(
                                        textDirection: TextDirection.rtl,
                                        text: TextSpan(
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                          children: [
                                            TextSpan(text: '$unit : '),
                                            WidgetSpan(
                                              child: Text(
                                                '$price ريال',
                                                textDirection:
                                                    TextDirection.ltr,
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      RichText(
                                        textDirection: TextDirection.rtl,
                                        text: TextSpan(
                                          style: TextStyle(
                                              color: Colors.grey, fontSize: 12),
                                          children: [
                                            TextSpan(text: 'الإجمالي: '),
                                            WidgetSpan(
                                              child: Text(
                                                '${itemTotal % 1 == 0 ? itemTotal.toInt() : itemTotal.toStringAsFixed(1)} ريال',
                                                textDirection:
                                                    TextDirection.ltr,
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.add_circle,
                                          color: Colors.green),
                                      onPressed: () {
                                        setState(() {
                                          final newQty = qty + step;
                                          cartItems[index]['qty'] = newQty;
                                          cartItems[index]['كمية'] = newQty;
                                        });
                                        updateCart();
                                      },
                                    ),
                                    Text(
                                      '\u200E${qty % 1 == 0 ? qty.toInt() : qty} $unit',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          if (qty > step) {
                                            final newQty = qty - step;
                                            cartItems[index]['qty'] = newQty;
                                            cartItems[index]['كمية'] = newQty;
                                          } else {
                                            cartItems.removeAt(index);
                                          }
                                        });
                                        updateCart();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الإجمالي:',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                              '\u200E${total % 1 == 0 ? total.toInt() : total.toStringAsFixed(1)} ريال',
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),

                        // اختيار العنوان
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('عنوان التوصيل',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                              SizedBox(height: 8),
                              isLoadingAddresses
                                  ? Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.red))
                                  : addresses.isEmpty
                                      ? Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.orange.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.warning,
                                                  color: Colors.orange),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'لا يوجد عناوين! أضف عنوان من قائمة عناويني',
                                                  style: TextStyle(
                                                      color: Colors.orange),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : Column(
                                          children: addresses.map((address) {
                                            final isSelected =
                                                selectedAddressId ==
                                                    address['id'];
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  selectedAddressId =
                                                      address['id'];
                                                  selectedAddressText =
                                                      address['عنوان'] ?? '';
                                                });
                                              },
                                              child: Container(
                                                margin:
                                                    EdgeInsets.only(bottom: 8),
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.red.shade50
                                                      : Colors.grey.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? Colors.red
                                                        : Colors.grey.shade300,
                                                    width: isSelected ? 2 : 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      isSelected
                                                          ? Icons
                                                              .radio_button_checked
                                                          : Icons
                                                              .radio_button_unchecked,
                                                      color: isSelected
                                                          ? Colors.red
                                                          : Colors.grey,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        address['اسم'] ??
                                                            'عنوان',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isSelected
                                                              ? Colors.red
                                                              : Colors.black,
                                                        ),
                                                      ),
                                                    ),
                                                    Icon(Icons.location_on,
                                                        color: isSelected
                                                            ? Colors.red
                                                            : Colors.grey,
                                                        size: 16),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),

                        // وقت التوصيل
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('وقت التوصيل',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('من:',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13)),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.red.shade200),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<int>(
                                              value: selectedFromHour,
                                              hint: Text('اختار',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                              isExpanded: true,
                                              items: availableFrom
                                                  .map((h) => DropdownMenuItem(
                                                        value: h,
                                                        child: Text(
                                                          formatHour(h),
                                                          style: TextStyle(
                                                              fontSize: 13),
                                                        ),
                                                      ))
                                                  .toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  selectedFromHour = val;
                                                  selectedToHour = null;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('إلى:',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13)),
                                        SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.red.shade200),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<int>(
                                              value: selectedToHour,
                                              hint: Text('اختار',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                              isExpanded: true,
                                              items: availableTo
                                                  .map((h) => DropdownMenuItem(
                                                        value: h,
                                                        child: Text(
                                                          formatHour(h),
                                                          style: TextStyle(
                                                              fontSize: 13),
                                                        ),
                                                      ))
                                                  .toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  selectedToHour = val;
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isDeliverySelected)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'التوصيل من $deliveryFromText إلى $deliveryToText 🕐',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  canOrder ? Colors.red : Colors.grey,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: canOrder
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InvoicePage(
                                          cartItems: cartItems,
                                          total: total,
                                          address: selectedAddressText,
                                          deliveryFrom: deliveryFromText,
                                          deliveryTo: deliveryToText,
                                          addressName: addresses.firstWhere(
                                                  (a) =>
                                                      a['id'] ==
                                                      selectedAddressId,
                                                  orElse: () => {})['اسم'] ??
                                              '',
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: Text(
                              !isAddressSelected
                                  ? 'اختار عنوان التوصيل أولاً'
                                  : !isDeliverySelected
                                      ? 'اختار وقت التوصيل أولاً'
                                      : 'تأكيد الطلب',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
