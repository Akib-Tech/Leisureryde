import 'package:flutter/material.dart';
import 'package:leisureryde/driver/driverregister.dart';
import 'package:leisureryde/methods/commonmethods.dart';
import 'package:leisureryde/methods/sharedpref.dart';
import 'package:leisureryde/userspage/login.dart';
import 'package:random_string/random_string.dart';


class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {

  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isDriver = false;

  final CommonMethods cMethods = CommonMethods();
   SharedPref pref = SharedPref();


  final Color gold = const Color(0xFFd4af37);
  final Color black = const Color(0xFF000000);

  checkIfNetwork() async{

    bool isInternet = await cMethods.checkConnectivity();
    if(isInternet){
      signUpFormVerification();
    }else{
      if(!mounted) return;
      cMethods.displaySnackBar("You are not connected to internet",context);
    }

  }

  signUpFormVerification() async{
    if(!emailController.text.contains("@")){
      cMethods.displaySnackBar("Incorrect email address", context);
    }else if(firstNameController.text.length < 3){
      cMethods.displaySnackBar("First name is too short", context);
    }else if(lastNameController.text.length < 3){
      cMethods.displaySnackBar("Last name is too short", context);
    }else if(userNameController.text.length < 3){
      cMethods.displaySnackBar("Username is too short", context);
    }else if(passController.text.length < 6){
      cMethods.displaySnackBar("Password is too short", context);
    }else if(phoneController.text.trim().length < 11){
      cMethods.displaySnackBar("Phone number cannot be less than 11", context);
    }else{
      String id = randomAlphaNumeric(10);
     cMethods.registerNewUsers(
        id,
        emailController.text,
        firstNameController.text,
        lastNameController.text,
        userNameController.text,
        passController.text,
        phoneController.text,
        context
      );
     await pref.savePhone(phoneController.text);
     await pref.saveUsername(userNameController.text);
     await pref.saveUserId(id);
    }

  }
  @override
  void dispose() {
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    userNameController.dispose();
    passController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Leisure Ryde", textAlign: TextAlign.center, style: TextStyle(color: gold,fontWeight: FontWeight.bold,fontSize:30,fontFamily: "Monospace"),),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    "Create a User Account",
                    style: TextStyle(
                        color: gold, fontWeight: FontWeight.bold, fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => isDriver = false);
                          Navigator.push(context, MaterialPageRoute(builder: (c) => SignupPage()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
                          decoration: BoxDecoration(
                            color: !isDriver ? Colors.black : Colors.white,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            "User",
                            style: TextStyle(
                              color: !isDriver ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          setState(() => isDriver = true);
                          Navigator.push(context, MaterialPageRoute(builder: (c) => DriverRegister()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
                          decoration: BoxDecoration(
                            color: isDriver ? Colors.black : Colors.white,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            "Driver",
                            style: TextStyle(
                              color: isDriver ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Email
                  _buildLabel("Email Address"),
                  _buildInputField(
                      "Enter your email", Icons.email, emailController),

                  const SizedBox(height: 20),


                  // First Name
                  _buildLabel("First Name"),
                  _buildInputField(
                      "Enter first name", Icons.person, firstNameController),

                  const SizedBox(height: 20),

                  // Last Name
                  _buildLabel("Last Name"),
                  _buildInputField(
                      "Enter last name", Icons.person, lastNameController),

                  const SizedBox(height: 20),

                  // Username
                  _buildLabel("Username"),
                  _buildInputField(
                      "Enter Username", Icons.person, userNameController),

                  const SizedBox(height: 20),

                  // Password
                  _buildLabel("Password"),
                  _buildInputField("Enter your password", Icons.lock,
                      passController,
                      isPassword: true),

                  const SizedBox(height: 25),

                  // Phone
                  _buildLabel("Phone Number"),
                  _buildInputField(
                      "Enter your phone number", Icons.phone, phoneController),

                  const SizedBox(height: 20),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
                        "Sign Up",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Already have an account?
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => LoginPage()));
                        },
                        child: Text(
                          "Sign In",
                          style: TextStyle(
                              color: gold, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  // Custom Label
  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Custom Input
  Widget _buildInputField(String hint, IconData icon, TextEditingController control,
      {bool isPassword = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TextField(
        controller: control,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: gold, width: 2)),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white),
          prefixIcon: Icon(icon, color: gold),
        ),
      ),
    );
  }
}
