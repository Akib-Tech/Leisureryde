import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminMethod{

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseDatabase dBase = FirebaseDatabase.instance;

  Future<List<Map<String,dynamic>?>> usersList()async{
    DatabaseReference fetchUserData = dBase.ref().child("users");

    final userList = await fetchUserData.get();

    List<Map<String, dynamic>? > result =[];

    for (var child in userList.children) {
      Map<String, dynamic>? data = Map<String, dynamic>.from(child.value as Map);
      result.add(data);
    }

    if(result.isNotEmpty){
      return result;
    }else{
      return [];
    }

  }

  Future<List<Map<String,dynamic>?>> driversList()async{
    DatabaseReference fetchDriversData = dBase.ref().child("drivers");
    final driversList = await fetchDriversData.get();

    List<Map<String, dynamic>? > result =[];

    for (var child in driversList.children) {
      Map<String, dynamic>? data = Map<String, dynamic>.from(child.value as Map);
      result.add(data);
    }

    if(result.isNotEmpty){
      return result;
    }else{
      return [];
    }

  }

  Future<List<Map<String,dynamic>?>> requestList()async{
      DatabaseReference fetchRequestData = dBase.ref().child("rideRequests");

      final requestsList = await fetchRequestData.get();

      List<Map<String, dynamic>? > result =[];

      for (var child in requestsList.children) {
        Map<String, dynamic>? data = Map<String, dynamic>.from(child.value as Map);
        result.add(data);
      }

      if(result.isNotEmpty){
        return result;
      }else{
        return [];
      }

    }
/*
  Future<List<Map<String,dynamic>?>> paymentList()async{
    DatabaseReference users = dBase.ref().child("users");
  }

 */
}