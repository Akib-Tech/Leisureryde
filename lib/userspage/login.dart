import 'package:flutter/material.dart';
import 'package:leisureryde/driver/driverlogin.dart';
import 'package:leisureryde/methods/commonmethods.dart';
import 'package:leisureryde/userspage/sign_up.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  bool isDriver = false;

  final CommonMethods cMethods = CommonMethods();

  final Color gold = const Color(0xFFD4AF37);
  final Color black = const Color(0xFF000000);

  void checkIfNetwork() async{

    bool isInternet = await cMethods.checkConnectivity();

    if(isInternet){
      loginValidation();
    }else{
      if(!mounted) return;
      cMethods.displaySnackBar("You are not connected to internet", context);
    }

  }


  loginValidation(){
     if(!emailController.text.contains("@")){
      cMethods.displaySnackBar("Incorrect email address", context);
    }else if(passController.text.trim().length < 6){
      cMethods.displaySnackBar("Password is incorrect", context);
    }else{
        cMethods.loginUser(emailController.text,passController.text,context);
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
      backgroundColor: black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20,vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Leisure Ryde", textAlign: TextAlign.center, style: TextStyle(color: gold,fontWeight: FontWeight.bold,fontSize:30,fontFamily: "Monospace"),),


                  const SizedBox(height: 20),

                  // Title
                  Text(
                    "Welcome Back, Sign-In as a user",
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
                          Navigator.push(context, MaterialPageRoute(builder: (c) => LoginPage()));
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
                          Navigator.push(context, MaterialPageRoute(builder: (c) => DriverLogin()));
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
                  _buildInputField("Enter your email", Icons.email,
                      emailController,
                      keyboardType: TextInputType.emailAddress),

                  const SizedBox(height: 20),

                  // Password
                  _buildLabel("Password"),
                  _buildInputField("Enter your password", Icons.lock,
                      passController,
                      isPassword: true),

                  const SizedBox(height: 25),

                  // Login Button
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
                        "Login",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Don't have an account?
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      const Text(
                        "Don’t have an account? ",
                        style: TextStyle(color: Colors.white),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignupPage()),
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
  Widget _buildInputField(String hint, IconData icon,
      TextEditingController control,
      {bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TextField(
        controller: control,
        obscureText: isPassword,
        keyboardType: keyboardType,
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
