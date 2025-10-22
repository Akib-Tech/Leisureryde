import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EntryPage extends StatefulWidget{
  const EntryPage({super.key});

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  final Color gold = const Color(0xFFD4AF37);
  final Color black = const Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor : black,
      body: SafeArea(
        child: Center(
          child:  Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Leisure Ryde",style: TextStyle(color: gold,fontSize: 50,fontWeight: FontWeight.bold,fontFamily: "Courier New"),),
              SizedBox(height: 50,),
              CupertinoActivityIndicator(color:Colors.white,radius: 50,)

            ],
          ),
        )
      )
  );

  }
}