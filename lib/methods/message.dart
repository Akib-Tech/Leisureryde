import 'package:firebase_database/firebase_database.dart';
import 'package:leisureryde/methods/commonMethods.dart';


  Stream<List<Map<String,dynamic>?>> fetchMessage() async*{
  DatabaseReference dbMessage = CommonMethods().dBase.ref().child("messages");

  final fetchMessage = await dbMessage.get();

   List<Map<String, dynamic>? > result =[];

  for (var child in fetchMessage.children) {
    Map<String, dynamic>? data = Map<String, dynamic>.from(child.value as Map);
    result.add(data);
  }

  yield result;

}