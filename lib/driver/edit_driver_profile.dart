import 'package:flutter/material.dart';
import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/userspage/login.dart';
import '../widgets/buttomnav.dart';

class EditDriverProfile extends StatefulWidget{
  const EditDriverProfile({super.key});

  @override
  State<EditDriverProfile> createState() => _EditDriverProfileState();

}

class _EditDriverProfileState extends State<EditDriverProfile>{

  final Color gold = const Color(0xFFFFD700);
  final Color black = Colors.black;

  final CommonMethods cMethods = CommonMethods();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();

  checkIfNetwork() async{
    bool isInternet = await cMethods.checkConnectivity();
    if(isInternet){
      validateEdit();
    }else{
      if(!mounted) return;
      cMethods.displaySnackBar("You are not connected to internet",context);
    }

  }

  validateEdit(){
    if(!emailController.text.contains("@")){
      cMethods.displaySnackBar("Incorrect email address", context);
    }else if(firstNameController.text.length < 3){
      cMethods.displaySnackBar("First name is too short", context);
    }else if(lastNameController.text.length < 3){
      cMethods.displaySnackBar("Last name is too short", context);
    }else if(userNameController.text.length < 3){
      cMethods.displaySnackBar("Username is too short", context);
    }else if(phoneNumberController.text.length < 9){
      cMethods.displaySnackBar("Phone number is too short", context);
    }else{
      cMethods.updateProfile(
          emailController.text,
          firstNameController.text,
          lastNameController.text,
          userNameController.text,
          phoneNumberController.text,
          context
      );
    }

  }
  @override
  void dispose() {
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    userNameController.dispose();
    phoneNumberController.dispose();
    super.dispose();
  }




  @override
  void initState() {
    super.initState();

  }
  @override
  Widget build(BuildContext context) {
    return  FutureBuilder<Map<String, dynamic>?>(
        future: cMethods.fetchingData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const LoginPage();
          }else {
            final data = snapshot.data!;
            firstNameController.text = data["firstname"] ?? "";
            lastNameController.text = data["lastname"] ?? "";
            userNameController.text = data["username"] ?? "";
            emailController.text = data["email"] ?? "";
            phoneNumberController.text = data["phone"] ?? "";


            return Scaffold(
              backgroundColor: Colors.white,
              body: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                        top: 60, left: 20, right: 20, bottom: 30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [black, Colors.black87, Colors.black54],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors
                                  .white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            const Text(
                              "Edit Profile",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const Spacer(flex: 2),
                          ],
                        ),
                        SizedBox(height: 5,),
                        Text("Leisure Ryde", style: TextStyle(color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                            fontFamily: "Monospace"),),

                        const SizedBox(height: 20),

                        // ---------- Profile Picture ----------
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            const CircleAvatar(
                              radius: 55,
                              backgroundImage: AssetImage(
                                  "assets/images/car.jpg"),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: gold,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                    Icons.camera_alt, color: Colors.black),
                                onPressed: () {
                                  // TODO: change profile picture
                                },
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ---------------- MAIN CONTENT ----------------
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          //Email
                          _buildLabel("Email"),
                          _buildInputField(
                              "Enter Email address", Icons.email, emailController),

                          const SizedBox(height: 20),

                          // First Name
                          _buildLabel("First Name"),
                          _buildInputField(
                              "Enter first name", Icons.person,
                              firstNameController),

                          const SizedBox(height: 20),

                          // Last Name
                          _buildLabel("Last Name"),
                          _buildInputField(
                              "Enter last name", Icons.person,
                              lastNameController),

                          const SizedBox(height: 20),

                          // Username
                          _buildLabel("Username"),
                          _buildInputField(
                              "Enter username", Icons.person,
                              userNameController),

                          const SizedBox(height: 20),

                          // Phone Number
                          _buildLabel("Phone Number"),
                          _buildInputField(
                              "Enter Phone number", Icons.phone,
                              phoneNumberController),

                          const SizedBox(height: 20),


                          // Save button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gold,
                              foregroundColor: black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                            onPressed: () {
                              checkIfNetwork();
                            },
                            child: const Text(
                              "Save Changes",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
              ,
              // ---------------- BOTTOM NAVIGATION ----------------
              bottomNavigationBar: const ButtomNav(),
            );
          }

        }
    ); }



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





