import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../common/auth_gate.dart';

class HospitalRegisterScreen extends StatefulWidget {
  const HospitalRegisterScreen({super.key});

  @override
  State<HospitalRegisterScreen> createState() =>
      _HospitalRegisterScreenState();
}

class _HospitalRegisterScreenState extends State<HospitalRegisterScreen> {
  int step = 0;
  bool isSubmitting = false;

  final AuthService _auth = AuthService();

  final hospitalName = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final pincode = TextEditingController();
  final contactName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    hospitalName.dispose();
    address.dispose();
    city.dispose();
    pincode.dispose();
    contactName.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  void nextStep() => setState(() => step++);
  void prevStep() => setState(() => step--);

  bool validateStep() {
    if (step == 0 && hospitalName.text.isEmpty) {
      showError("Enter hospital name");
      return false;
    }

    if (step == 1 &&
        (address.text.isEmpty || city.text.isEmpty || pincode.text.isEmpty)) {
      showError("Fill all address fields");
      return false;
    }

    if (step == 2 &&
        (contactName.text.isEmpty ||
            email.text.isEmpty ||
            phone.text.isEmpty ||
            password.text.isEmpty)) {
      showError("Fill all details");
      return false;
    }

    return true;
  }

  void showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void registerHospital() async {
    if (isSubmitting) return;

    setState(() => isSubmitting = true);

    try {
      await _auth.registerHospital(
        email: email.text.trim(),
        password: password.text.trim(),
        hospitalName: hospitalName.text.trim(),
        address: address.text.trim(),
        city: city.text.trim(),
        pincode: pincode.text.trim(),
        contactName: contactName.text.trim(),
        phone: phone.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hospital Registered Successfully")),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Hospital Registration"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 35,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      getStepTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    getStepContent(),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (step > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: prevStep,
                              child: const Text("Back"),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (isSubmitting) return;
                              if (!validateStep()) return;

                              if (step == 2) {
                                registerHospital();
                              } else {
                                nextStep();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB71C1C),
                              foregroundColor: Colors.white,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(step == 2 ? "Submit" : "Next"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).viewInsets.bottom,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String getStepTitle() {
    switch (step) {
      case 0:
        return "Hospital Information";
      case 1:
        return "Address Details";
      case 2:
        return "Contact & Login Details";
      default:
        return "";
    }
  }

  Widget getStepContent() {
    switch (step) {
      case 0:
        return TextField(
          controller: hospitalName,
          decoration: const InputDecoration(
            labelText: "Hospital Name",
            prefixIcon: Icon(Icons.local_hospital),
          ),
        );

      case 1:
        return Column(
          children: [
            TextField(
              controller: address,
              decoration: const InputDecoration(
                labelText: "Address",
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: city,
              decoration: const InputDecoration(labelText: "City"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pincode,
              decoration: const InputDecoration(labelText: "Pincode"),
            ),
          ],
        );

      case 2:
        return Column(
          children: [
            TextField(
              controller: contactName,
              decoration: const InputDecoration(
                labelText: "Contact Person",
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              decoration: const InputDecoration(
                labelText: "Phone",
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        );

      default:
        return Container();
    }
  }
}
