import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:leisureryde/methods/commonmethods.dart';
import 'package:leisureryde/driver/driverlogin.dart';
import 'package:leisureryde/methods/filemanager.dart';
import 'package:leisureryde/methods/sharedpref.dart';
import 'package:leisureryde/userspage/sign_up.dart';
import 'package:random_string/random_string.dart';

class DriverRegister extends StatefulWidget {
  const DriverRegister({super.key});

  @override
  State<DriverRegister> createState() => _DriverRegisterState();
}

class _DriverRegisterState extends State<DriverRegister>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final CommonMethods cMethods = CommonMethods();
  final SharedPref pref = SharedPref();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  bool _animationReady = false;
  bool isDriver = true;
  bool choose = false;

  final Color gold = const Color(0xFFd4af37);
  final Color black = Colors.black;

  @override
  void initState() {
    super.initState();

    // Initialize animation safely
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        setState(() => _animationReady = true);
      }
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    if (_fadeController.isAnimating || _fadeController.isCompleted) {
      _fadeController.stop();
    }
    _fadeController.dispose();
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    userNameController.dispose();
    passController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  File file = File("");

  String? fileLink;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
       file =  File(result.files.single.path!);
      //fileLink =  await FileManager().uploadFile(file,context);

      choose = true;
    }
  }


  Future<void> checkIfNetwork() async {
    bool isInternet = await cMethods.checkConnectivity();
    if (!mounted) return;
    if (isInternet) {
      driverFormVerification();
    } else {
      cMethods.displaySnackBar("You are not connected to internet", context);
    }
  }

  void driverFormVerification() async{
    if (!emailController.text.contains("@")) {
      cMethods.displaySnackBar("Incorrect email address", context);
    } else if (firstNameController.text.length < 3) {
      cMethods.displaySnackBar("First name is too short", context);
    } else if (lastNameController.text.length < 3) {
      cMethods.displaySnackBar("Last name is too short", context);
    } else if (userNameController.text.length < 3) {
      cMethods.displaySnackBar("Username is too short", context);
    } else if (passController.text.length < 6) {
      cMethods.displaySnackBar("Password is too short", context);
    } else if (phoneController.text.trim().length < 11) {
      cMethods.displaySnackBar("Phone number cannot be less than 11", context);
    } else {
     String id =  randomAlphaNumeric(10);
     if(fileLink != null) {
       cMethods.registerNewDriver(
         id,
         emailController.text,
         firstNameController.text,
         lastNameController.text,
         userNameController.text,
         passController.text,
         phoneController.text,
         fileLink!,
         context,
       );

       await pref.saveUserId(id);
       await pref.saveUsername(userNameController.text);
       await pref.savePhone(phoneController.text);
       await pref.saveStatus("yes");
     }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _animationReady ? _fadeAnimation.value : 1.0,
            child: child,
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
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
                const SizedBox(height: 15),
                Text(
                  "Driver Registration",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: black,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 15),

                // Toggle Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildToggleButton(
                      title: "Driver",
                      isActive: isDriver,
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    _buildToggleButton(
                      title: "User",
                      isActive: !isDriver,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => const SignupPage()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                _buildLabel("Email Address"),
                _buildInputField("Enter your email", Icons.email, emailController),

                _buildLabel("First Name"),
                _buildInputField("Enter first name", Icons.person, firstNameController),

                _buildLabel("Last Name"),
                _buildInputField("Enter last name", Icons.person, lastNameController),

                _buildLabel("Username"),
                _buildInputField("Enter username", Icons.person, userNameController),

                _buildLabel("Password"),
                _buildInputField(
                  "Enter password",
                  Icons.lock,
                  passController,
                  isPassword: true,
                ),

                _buildLabel("Phone Number"),
                _buildInputField("Enter phone number", Icons.phone, phoneController),

                const SizedBox(height: 25),

                _buildLabel("Upload Driving Credentials"),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: pickFile,
                      child: choose ?  Text("Selected: ${file.path.split('/').last}") : const Text("Select File"),
                    ),
                    /*if (file != null) ...[
                      const SizedBox(height: 10),
                      Text("Selected: ${_file!.path.split('/').last}"),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: uploadFile,
                        child: const Text("Upload File"),
                      ),
                    ],*/
                  ],
                ),

                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: checkIfNetwork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(color: Colors.black87),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (c) => const DriverLogin()),
                        );
                      },
                      child: Text(
                        "Sign In",
                        style: TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
        decoration: BoxDecoration(
          color: isActive ? gold : Colors.grey[200],
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: gold),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInputField(String hint, IconData icon, TextEditingController control,
      {bool isPassword = false}) {
    return TextField(
      controller: control,
      obscureText: isPassword,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: gold),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black45),
        filled: true,
        fillColor: Colors.grey[100],
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: gold, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12),
        ),
      ),
    );
  }
}
