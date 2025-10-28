import "dart:math";

import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:shared_preferences/shared_preferences.dart";

class SharedPref{

  static String idKey = "id";
  static String nameKey = "username";
  static String phoneKey = "phone";
  static String statKey = "status";
  static String driverId = "driver";
  static String bookStatus = "bookStatus";
  static String reject = "reject";

  static String pickup ="pickup";
  static String destination = "destination";

  Future<bool> saveUserId(String? id) async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.setString(idKey, id!);
  }


  Future<bool> saveUsername(String username) async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.setString(nameKey, username);
  }

  Future<bool> savePhone(String phone) async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.setString(phoneKey, phone);
  }

  Future<bool> saveStatus(String status) async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.setString(statKey, status);
  }

  Future<bool> setDriver(String? id)async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.setString(driverId, id!);
  }

  Future<bool>bookState (String id) async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    print("YOu booked me : $id");
    return pref.setString(bookStatus, id);
    }

  Future<String> getBookStatus() async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(bookStatus) ?? "";
  }

  Future<String?> getUserId() async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(idKey) ?? "103092de";
  }

  Future<String?> getUsername() async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(nameKey) ?? "Ibraheem";
  }

  Future<String?> getPhone() async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(phoneKey) ?? "09077664433";
  }

  Future<String?> getStatus() async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(statKey) ?? "on";
  }

  Future<String?> getDriver() async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString(driverId) ?? "";
  }

  Future<bool> storeReject(rejectList) async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.setStringList(reject, rejectList);
  }

  Future<List<String>?> getRejected() async{
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getStringList(reject);
  }

}
