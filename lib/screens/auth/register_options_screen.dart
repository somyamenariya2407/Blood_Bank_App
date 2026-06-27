import 'package:flutter/material.dart';
import 'user_register_screen.dart';
import 'hospital_register_screen.dart';

class RegisterOptionsScreen extends StatelessWidget {
  const RegisterOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🔴 LOGO (SAME AS LOGIN)
            Column(
              children: [
                Container(
                  height: 70,
                  width: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.water_drop,
                      color: Colors.white, size: 35),
                ),
                const SizedBox(height: 10),
                const Text(
                  "BloodLink",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                )
              ],
            ),

            const SizedBox(height: 40),

            /// 📦 MAIN CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [

                  const Text(
                    "Choose Registration Type",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// 👤 USER REGISTER
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserRegisterScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.person, color: Color(0xFFB71C1C)),
                          SizedBox(width: 12),
                          Expanded(child: Text("Register as User / Donor")),
                          Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🏥 HOSPITAL REGISTER
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HospitalRegisterScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.local_hospital,
                              color: Color(0xFFB71C1C)),
                          SizedBox(width: 12),
                          Expanded(child: Text("Register as Hospital")),
                          Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Back to Login"),
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
