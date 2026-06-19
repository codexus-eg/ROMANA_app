import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPScreen extends StatefulWidget {
  final String generatedOTP;
  final Function() onVerified;

  OTPScreen({required this.generatedOTP, required this.onVerified});

  @override
  _OTPScreenState createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.red,
          title: Text('التحقق من الكود',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email, size: 80, color: Colors.red),
              SizedBox(height: 24),
              Text(
                'أدخل كود التحقق المرسل لإيميلك',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  labelText: 'كود التحقق',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.red.shade50,
                  counterText: '',
                ),
                onChanged: (value) {
                  if (value.length == 6) {
                    _verifyOTP(value);
                  }
                },
              ),
              SizedBox(height: 30),
              _isLoading
                  ? CircularProgressIndicator(color: Colors.red)
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _verifyOTP(_pinController.text),
                        child: Text('تأكيد الكود',
                            style:
                                TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إعادة إرسال الكود',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _verifyOTP(String pin) async {
    if (pin.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('يرجى إدخال الكود كاملاً'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (pin == widget.generatedOTP) {
      setState(() => _isLoading = true);
      await widget.onVerified();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('هذا الكود خطأ، حاول مرة أخرى'),
            backgroundColor: Colors.red),
      );
      _pinController.clear();
    }
  }
}
