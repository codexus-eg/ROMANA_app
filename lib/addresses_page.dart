import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class AddressesPage extends StatefulWidget {
  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  String customerId = '';
  List<Map<String, dynamic>> addresses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    customerId = prefs.getString('customerId') ?? '';

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
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteAddress(String addressId) async {
    await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('addresses')
        .doc(addressId)
        .delete();
    await loadAddresses();
  }

  void showAddAddressDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddAddressSheet(
        customerId: customerId,
        onSaved: () {
          Navigator.pop(context);
          loadAddresses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: Text('عناويني 📍',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.red))
            : Column(
                children: [
                  Expanded(
                    child: addresses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_off,
                                    size: 80, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('لا يوجد عناوين بعد',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: addresses.length,
                            itemBuilder: (context, index) {
                              final address = addresses[index];
                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                margin: EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.shade50,
                                    child: Icon(Icons.location_on,
                                        color: Colors.red),
                                  ),
                                  title: Text(
                                    address['اسم'] ?? 'عنوان',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    address['عنوان'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () =>
                                        deleteAddress(address['id']),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: showAddAddressDialog,
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text('إضافة عنوان جديد',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class AddAddressSheet extends StatefulWidget {
  final String customerId;
  final VoidCallback onSaved;

  AddAddressSheet({required this.customerId, required this.onSaved});

  @override
  State<AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<AddAddressSheet> {
  final _nameController = TextEditingController();
  LatLng? selectedLocation;
  GoogleMapController? mapController;
  bool isSaving = false;

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
        setState(() => selectedLocation = latLng);
        mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هذه الخدمة لا تتوفر في هذه المنطقة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديد موقعك!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> saveAddress() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('أدخل اسم العنوان!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('اختار الموقع على الخريطة!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(widget.customerId)
        .collection('addresses')
        .add({
      'اسم': _nameController.text,
      'عنوان': getAddressFromLatLng(selectedLocation!),
      'lat': selectedLocation!.latitude,
      'lng': selectedLocation!.longitude,
      'createdAt': DateTime.now().toString(),
    });

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('إضافة عنوان جديد',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),

              // اسم العنوان
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم العنوان (مثال: المنزل، العمل)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.label, color: Colors.red),
                  filled: true,
                  fillColor: Colors.red.shade50,
                ),
              ),
              SizedBox(height: 16),

              // زرار الموقع الحالي
              InkWell(
                onTap: getCurrentLocation,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      topLeft: Radius.circular(12),
                    ),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.my_location, color: Colors.red),
                      SizedBox(width: 8),
                      Text('اختر موقعك الحالي',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              // الخريطة
              ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(18.2164, 42.5053),
                      zoom: 10,
                    ),
                    onMapCreated: (controller) {
                      mapController = controller;
                    },
                    onTap: (latLng) {
                      if (isInAseer(latLng)) {
                        setState(() => selectedLocation = latLng);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('هذه الخدمة لا تتوفر في هذه المنطقة'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    markers: selectedLocation != null
                        ? {
                            Marker(
                              markerId: MarkerId('selected'),
                              position: selectedLocation!,
                            )
                          }
                        : {},
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ),
              ),

              if (selectedLocation != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('تم تحديد الموقع ✅',
                          style: TextStyle(color: Colors.green)),
                    ],
                  ),
                ),

              SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isSaving ? null : saveAddress,
                  child: isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('حفظ العنوان',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
