import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:leisureryde/methods/sharedpref.dart';


class FileManager{

  final storageRef = FirebaseStorage.instance.ref();


  Future<String> uploadFile(file,context) async{

    String? id = await SharedPref().getUserId();
    String? downloadUrl;
    try {
      final fileRef = storageRef.child("License").child(id!).child("${file.path.split('/').last}");
      await fileRef.putFile(file);

      downloadUrl = await fileRef.getDownloadURL();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded! URL: $downloadUrl')),
      );
        return downloadUrl;

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    return downloadUrl!;
  }


}