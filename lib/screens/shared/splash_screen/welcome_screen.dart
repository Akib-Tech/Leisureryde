import 'package:flutter/material.dart';
import 'package:leisureryde/screens/shared/auth/login_screen.dart';
import 'package:leisureryde/screens/shared/auth/signup_screen.dart';
import 'package:leisureryde/widgets/carousel.dart';
import '../../../widgets/button.dart';

class WelcomePage extends StatefulWidget{
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();

}

class _WelcomePageState extends State<WelcomePage> {
  final Color gold = const Color(0xFFD4AF37);
  final Color black = const Color(0xFF000000);
  @override
  Widget build(BuildContext context) {

    return Scaffold(
        backgroundColor: black,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20,),
                Text("Leisure Ryde",style: TextStyle(color: gold,fontSize: 50,fontWeight: FontWeight.bold,fontFamily: "Courier New"),),
                SizedBox(height: 30,),
                Text("PROFESSIONAL LUXURY CAR SERVICE",textAlign: TextAlign.center,style: TextStyle(color: Colors.white,fontSize: 30,fontWeight: FontWeight.bold,fontFamily: "Courier New"),),
                SizedBox(height: 5,),
                SizedBox(
                  width: 700,
                  height:400,
                  child:  CustomCarousel(
                    height: 500,
                    activeDotColor: Colors.amber,
                    inactiveDotColor: Colors.grey,
                    items: [
                      Image.asset("assets/images/car2.jpg"),
                      Image.asset("assets/images/car4.jpg"),
                      Image.asset("assets/images/locatecar.jpg"),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30,vertical: 100),
                  child: Column(
                    children: [
                      buildActionButton(
                          "SIGN UP", gold, black, () {
                        Navigator.push(context, MaterialPageRoute(
                            builder: (c) => SignupScreen()));
                      }),
                      const SizedBox(height: 14),
                      buildActionButton(
                          "LOGIN", black, gold,
                              () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (c) => LoginScreen()));
                          }),
                    ],
                  ),
                ),




              ],
            ),
          ),
        )
    );

  }
}