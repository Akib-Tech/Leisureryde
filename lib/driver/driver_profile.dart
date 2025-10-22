import 'package:flutter/material.dart';
import 'package:leisureryde/userspage/profile_edit.dart';
import 'package:leisureryde/userspage/sign_up.dart';
import '../methods/commonMethods.dart';
import '../widgets/buttomnav.dart';
import '../widgets/button.dart';

class DriverProfile extends StatefulWidget {
  const DriverProfile({super.key});

  @override
  State<DriverProfile> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<DriverProfile> {
  final Color gold = const Color(0xFFFFD700);
  final Color black = Colors.black;

  final CommonMethods cMethods = CommonMethods();



  @override
  void initState() {
    super.initState();
  }


  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 25),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: gold.withOpacity(0.6), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: gold.withOpacity(0.2),
            child: Icon(icon, color: gold),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: black,
        iconTheme: const IconThemeData( // 👈 this sets back button color
          color: Colors.white,
        ),
        elevation: 1,
        title: const Text(
          "Profile",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: "Edit Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const EditProfile()),
              );
            },
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
          future: cMethods.fetchingData(),
          builder: (context, snapshot) {

            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final firstName = data["firstname"] ?? "";
            final lastName = data["lastname"] ?? "";
            final username = data["username"] ?? "";
            final email = data["email"] ?? "";
            final phone = data["phone"] ?? "";
            final creation = data["createdAt"] ?? "";

            return SingleChildScrollView(
              child: Column(
                children: [
                  // ✅ HEADER WITH OVERLAYED IMAGE
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: black,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 5,),
                            Text("Leisure Ryde", style: TextStyle(color: gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 30,
                                fontFamily: "Monospace"),),
                            SizedBox(height: 10,),

                            Text("$username", style: TextStyle(color: gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 25,
                                fontFamily: "Monospace"),),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: -60,
                        child: CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.white,
                          child: const CircleAvatar(
                            radius: 65,
                            backgroundImage: AssetImage(
                                "assets/images/car.jpg"),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80), // give space for overlay

                  // ✅ Centered Name + Email
                  Text(
                    "$firstName $lastName",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$email",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),

                  const SizedBox(height: 30),

                  // ✅ Info Cards
                  _buildInfoCard("Phone Number", "$phone", Icons.phone),
                  _buildInfoCard("Joined", "$creation", Icons.calendar_today),

                  const SizedBox(height: 40),

                  // ✅ Logout & Delete Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Column(
                      children: [
                        buildActionButton(
                            "Logout", Colors.white, Colors.red, () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (c) => SignupPage()));
                        }),
                        const SizedBox(height: 14),
                        buildActionButton(
                            "Delete Account", Colors.white, Colors.red,
                                () {
                              // TODO: delete
                            }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } ),
      // ✅ Same bottom navigation bar flow
      bottomNavigationBar: const ButtomNav(),
    );
  }
}
