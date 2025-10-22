import 'package:flutter/material.dart';
import 'package:leisureryde/driver/driverregister.dart';
import 'package:leisureryde/methods/commonmethods.dart';
import 'package:leisureryde/userspage/login.dart';

class DriverLogin extends StatefulWidget {
  const DriverLogin({super.key});

  @override
  State<DriverLogin> createState() => _DriverLoginState();
}

class _DriverLoginState extends State<DriverLogin> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  bool isDriver = true;
  final CommonMethods cMethods = CommonMethods();

  final Color gold = const Color(0xFFD4AF37);
  final Color black = const Color(0xFF000000);

  void checkIfNetwork() async {
    bool isInternet = await cMethods.checkConnectivity();

    if (isInternet) {
      driverValidation();
    } else {
      if (!mounted) return;
      cMethods.displaySnackBar("You are not connected to the internet", context);
    }
  }

  void driverValidation() {
    if (!emailController.text.contains("@")) {
      cMethods.displaySnackBar("Incorrect email address", context);
    } else if (passController.text.trim().length < 6) {
      cMethods.displaySnackBar("Password is incorrect", context);
    } else {
      cMethods.loginDriver(emailController.text, passController.text, context);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 👈 White background for Driver Login
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Leisure Ryde",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                    fontFamily: "Monospace",
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Welcome Back, Driver",
                  style: TextStyle(
                    color: black,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Toggle Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Driver toggle
                    GestureDetector(
                      onTap: () {
                        setState(() => isDriver = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 25),
                        decoration: BoxDecoration(
                          color: isDriver ? gold : Colors.white,
                          border: Border.all(color: black),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          "Driver",
                          style: TextStyle(
                            color: isDriver ? Colors.white : black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // User toggle
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 25),
                        decoration: BoxDecoration(
                          color: isDriver ? Colors.white : gold,
                          border: Border.all(color: black),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text(
                          "User",
                          style: TextStyle(
                            color: isDriver ? black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Email field
                _buildLabel("Email Address", black),
                _buildInputField(
                  "Enter your email",
                  Icons.email,
                  emailController,
                  textColor: black,
                ),

                const SizedBox(height: 20),

                // Password field
                _buildLabel("Password", black),
                _buildInputField(
                  "Enter your password",
                  Icons.lock,
                  passController,
                  isPassword: true,
                  textColor: black,
                ),

                const SizedBox(height: 25),

                // Login Button
                ElevatedButton(
                  onPressed: checkIfNetwork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Login",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 25),

                // Sign Up prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account? ",
                      style: TextStyle(color: black),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DriverRegister()),
                        );
                      },
                      child: Text(
                        "Sign Up",
                        style: TextStyle(
                            color: gold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(
          text,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildInputField(
      String hint,
      IconData icon,
      TextEditingController control, {
        bool isPassword = false,
        TextInputType keyboardType = TextInputType.text,
        required Color textColor,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TextField(
        controller: control,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: textColor),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700]),
          prefixIcon: Icon(icon, color: gold),
        ),
      ),
    );
  }
}
