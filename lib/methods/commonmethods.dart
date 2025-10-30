import 'dart:async';
import 'dart:core';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:leisureryde/driver/driver_dashboard.dart';
import 'package:leisureryde/methods/driversmethod.dart';
import 'package:leisureryde/methods/sharedpref.dart';
import 'package:leisureryde/userspage/home.dart';
import 'package:leisureryde/userspage/login.dart';
import 'package:leisureryde/userspage/profile.dart';
import '../widgets/loadingDialog.dart';
import 'package:leisureryde/globa/global_var.dart';
import 'dart:convert';
import 'package:http/http.dart'  as http ;


class CommonMethods {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseDatabase dBase = FirebaseDatabase.instance;
  late final DatabaseReference rideRequestRef = dBase.ref("rideRequests");

  final SharedPref pref = SharedPref();

  //final Drivers driverMethod = Drivers();

  final StreamController<Map<String, String>> rideRequestStream =
  StreamController.broadcast();

  /// ✅ Check internet connectivity
  Future<bool> checkConnectivity() async {
    var result = await Connectivity().checkConnectivity();
    return true;
    // (result == ConnectivityResult.mobile || result == ConnectivityResult.wifi);
  }

  /// ✅ Show snackbar message
  void displaySnackBar(String messageText, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messageText,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ✅ Show loading dialog
  void loadDialog(String message, BuildContext context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => LoadingDialog(messageText: message),
    );
  }






  Future<void> registerNewUsers(
     String id, // your own generated dynamic ID
     String email,
     String firstname,
     String lastname,
     String username,
     String password,
     String phone,
     BuildContext context,
  ) async {
    loadDialog("Registering user...", context);
    try {
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final firebaseUser = userCredential.user;
      Navigator.pop(context); // close loading dialog

      if (firebaseUser != null) {
        DatabaseReference userRef = dBase.ref().child("users").child(id);
        Map<String, dynamic> userData = {
          "id": id,
          "email": email.trim(),
          "firstname": firstname.trim(),
          "lastname": lastname.trim(),
          "username": username.trim(),
          "phone": phone.trim(),
          "createdAt": DateTime.now().toIso8601String(),
          "blockStatus": "no",
        };

        await userRef.set(userData);

        displaySnackBar("Account created successfully!", context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        displaySnackBar("Account creation failed. Try again.", context);
      }
    } catch (error) {
      Navigator.pop(context);
      String message = "Registration failed.";
      if (error is FirebaseAuthException) {
        if (error.code == 'email-already-in-use') {
          message = "This email is already registered.";
        } else if (error.code == 'weak-password') {
          message = "Password should be at least 6 characters.";
        } else if (error.code == 'invalid-email') {
          message = "Invalid email format.";
        }
      }
      displaySnackBar(message, context);
    }
  }

  /// 🔹 LOGIN USER (finds user by email, retrieves their dynamic ID)
  Future<void> loginUser(
     String email,
     String password,
     BuildContext context,
  ) async {
    loadDialog("Verifying user...", context);

    try {
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) throw FirebaseAuthException(code: "user-not-found");

      // Fetch all users to find the one that matches the email
      final snapshot = await dBase.ref().child("users").get();
      if (!snapshot.exists) {
        Navigator.pop(context);
        displaySnackBar("No users found in database.", context);
        return;
      }

      Map<String, dynamic>? userData;
      for (final child in snapshot.children) {
        final data = Map<String, dynamic>.from(child.value as Map);
        if (data['email'] == email.trim()) {
          userData = data;
          break;
        }
      }

      if (userData == null) {
        Navigator.pop(context);
        displaySnackBar("User record not found in database.", context);
        return;
      }

      // Save user info locally
      await SharedPref().saveUserId(userData['id']);
      await SharedPref().saveUsername(userData['username']);
      await SharedPref().savePhone(userData['phone']);

      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (error) {
      Navigator.pop(context);
      String message = "Login failed. Please try again.";
      if (error is FirebaseAuthException) {
        if (error.code == 'user-not-found') message = "No user found with this email.";
        if (error.code == 'wrong-password') message = "Incorrect password.";
        if (error.code == 'invalid-email') message = "Invalid email address.";
      }
      displaySnackBar(message, context);
    }
  }
  /// ✅ Fetch user data from Firebase
  Future<Map<String, dynamic>?> fetchingData() async{
    final user = await SharedPref().getUserId();
    if(user != null){
      final event = await dBase.ref().child("users").child(user).once();
      if (event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
    }
    return null;
  }

  /// ✅ Update user profile
  Future<void> updateProfile(
      String email,
      String firstname,
      String lastname,
      String username,
      String phone,
      BuildContext context,
      ) async {
    try {
      final user = await SharedPref().getUserId();
      if (user != null) {
        final userRef = dBase.ref().child("users").child(user);
        Map<String, dynamic> updateData = {
          "email": email.trim(),
          "firstname": firstname.trim(),
          "lastname": lastname.trim(),
          "username": username.trim(),
          "phone": phone.trim(),
        };

        userRef.set(updateData);

        displaySnackBar("Profile successfully updated.", context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
      } else {
        displaySnackBar("User not logged in.", context);
      }
    } catch (e) {
      displaySnackBar(e.toString(), context);
    }
  }

  /// ✅ Register new driver
  Future<void> registerNewDriver(
      String id,
      String email,
      String firstname,
      String lastname,
      String username,
      String password,
      String phone,
      String profileLink,
      BuildContext context,
      ) async {
    loadDialog("Registering driver...", context);
    try {
      final UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final User? firebaseUser = userCredential.user;
      Navigator.pop(context); // Close loading dialog

      if (firebaseUser != null) {
        DatabaseReference driverRef = dBase.ref().child("drivers").child(id);

        Map<String, dynamic> driverData = {
          "id": id,
          "email": email.trim(),
          "firstname": firstname.trim(),
          "lastname": lastname.trim(),
          "username": username.trim(),
          "phone": phone.trim(),
          "status" : "on",
          "driving" : "yes",
          "licence": profileLink,
          "createdAt": DateTime.now().toIso8601String(),
          "blockStatus": "no",
        };

        await driverRef.set(driverData);

        displaySnackBar("Driver account created successfully!", context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverDashboard()),
        );
      } else {
        displaySnackBar("Driver account creation failed.", context);
      }
    } catch (error) {
      displaySnackBar(error.toString(), context);
    }
  }

  /// ✅ Login driverZee
  Future<void> loginDriver(String email, String password, BuildContext context) async {
    loadDialog("Verifying driver...", context);
    try {
      final UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      DatabaseReference driverRef = dBase.ref().child("drivers");
      final event = await driverRef.get();

      if (userCredential.user != null) {
        for (var child in event.children) {
          final data = Map<String, dynamic>.from(child.value as Map);

          if (data['email'] == email.trim() ) {
            final driverData = data;
            await SharedPref().saveUserId(driverData['id']);
            await SharedPref().saveUsername(driverData['username']);
            await SharedPref().savePhone(driverData['phone']);
            await SharedPref().saveStatus(driverData['status']);

            break;
          }
        }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverDashboard()),
          );
        }else {
        displaySnackBar("Incorrect login details.", context);
      }
    } catch (error) {
      Navigator.pop(context);
      displaySnackBar(error.toString(), context);
    }
  }

  /// ✅ Create a new ride request
  Future<void> findRider(
      double pickupLat,
      double pickupLng,
      double destLat,
      double destLng,
      ) async {
    User? user = auth.currentUser;
    if (user == null) return;

    String requestId = DateTime.now().microsecondsSinceEpoch.toString();
    String? myId = await pref.getUserId();
    Map<String, dynamic> rideData = {
      "request_id": requestId,
      "passenger_id": myId,
      "pickup": {"lat": pickupLat, "lng": pickupLng},
      "destination": {"lat": destLat, "lng": destLng},
      "status": "pending",
    };

    await rideRequestRef.child(requestId).set(rideData);
    //displaySnackBar("✅ Ride request created successfully", context);
  }


  Future<void> notifyDriver() async{
    DatabaseReference driver = dBase.ref().child("drivers");
    final event =  await driver.get();

    for (var child in event.children) {
      final data = Map<String, dynamic>.from(child.value as Map);

        if(data['status'] == "on"){
        }
    }

    }




  /// ✅ Notify driver in real-time
Future<Map<String, String?>> driverRideNotice(BuildContext context,)  {
    final completer = Completer<Map<String, String?>>();
    rideRequestRef.onChildAdded.listen((event) async {

      final rideData = Map<String, dynamic>.from(event.snapshot.value as Map);

      final pickup = await getAddressFromCoordinates(rideData['pickup']['lat'],rideData['pickup']['lng']);
      final destination = await getAddressFromCoordinates(rideData['destination']['lat'],rideData['destination']['lng']);

      completer.complete({
        "pickup": pickup,
        "destination": destination,
      });
    });

    return completer.future;
  }

  //

  Future<String> getAddressFromCoordinates(double lat, double lng) async {

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$googleMapKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
       return data['results'][0]['formatted_address'];
      }
    }

    return "Address not found";
  }



  Future<Map<dynamic,dynamic>?> driverOnline() async {
    final ref = FirebaseDatabase.instance.ref("drivers").child(
        "E0mZe7iQXTMbwSFvsvxxhF50tTA3");

    final snapshot = await ref.get();

    if(snapshot.exists){
      return snapshot.value  as Map<dynamic, dynamic>;
    }else{
      return null;
    }
  }


  setDriverStatus(status) async{
    final id = await SharedPref().getUserId();
    late String driveStatus;
    if(id != null){
      final userRef = dBase.ref("drivers").child(id).child("status");

      if(status == true){
        driveStatus = "on";
      }else{
        driveStatus = "off";
      }
      userRef.update({"status" : driveStatus});
    }

  }


  Future<Map<String,dynamic>?> getProfile(String id) async{

    DatabaseReference dataList = dBase.ref().child("drivers").child(id);
    final snapshot = await dataList.get();

    if(snapshot.exists){
      return  Map<String,dynamic>.from(snapshot.value as Map);
    }

    return null;

  }


  Future<Map<String,dynamic>?> checkMapState() async{
      String booked = await SharedPref().getBookStatus();
      if(booked != "") {
        DatabaseReference mapStatus = dBase.ref().child("rideRequests").child(
            booked);
        final fetchData = await mapStatus.get();

        Map<String, dynamic>? result = Map<String, dynamic>.from(
            fetchData.value as Map);

        if (result.isNotEmpty && result['status'] != 'completed') {
          return result;
        }

        return null;
      }
      return null;
  }


}
