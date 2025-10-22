import 'package:flutter/material.dart';
import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/methods/sharedpref.dart';
import 'package:leisureryde/userspage/riderequest.dart';
import '../widgets/buttomnav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color gold = const Color(0xFFd4af37);
  final Color black = Colors.black;
  final CommonMethods cMethods = CommonMethods();

  SharedPref pref =  SharedPref();

  Future<Map<String,dynamic>?> getInfo() async{

      await SharedPref().bookState("");

      final Map<String,String?> info = {
          "id" : "xsi9w93iddodid",
          "username" : "xsi9w93iddodid",
          "phone" : "xsi9w93iddodid",
       };

      final Map<String,dynamic>? dbInfo = await cMethods.fetchingData();



      if(dbInfo != null){
        return dbInfo;
      }else{
        return info;
      }

  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      body: FutureBuilder<Map<String,dynamic>?>(
          future: getInfo(),
          builder: (context, snapshot) {
            final Map<String,dynamic>? newdata = snapshot.data;
            return SafeArea(
              child: SingleChildScrollView(
                  padding: EdgeInsets.only(top: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        decoration: const BoxDecoration(
                          //color: Colors.black,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top row with profile + actions
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left side: profile + welcome
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                          Icons.person, color: Colors.black),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        Text(
                                          "Welcome,",
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text("${newdata?['username'] ?? 'User' }",
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Right side: action buttons
                             /*  Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {},
                                      icon: const Icon(
                                          Icons.call, color: Colors.black),
                                      tooltip: "Call Support",
                                    ),
                                    IconButton(
                                      onPressed: () {},
                                      icon: const Icon(
                                          Icons.chat, color: Colors.black),
                                      tooltip: "Chat",
                                    ),
                                    IconButton(
                                      onPressed: () {},
                                      icon: const Icon(
                                          Icons.history, color: Colors.black),
                                      tooltip: "Ride History",
                                    ),
                                  ],
                                ),
                              */],
                            ),

                            const SizedBox(height: 20),

                            // Search Pickup bar
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.search, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text(
                                    "Where to?",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 30),


                      Center(
                          child: Text(
                            "Choose A Ride", textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.w600),)
                      ),

                      SizedBox(height: 30,),


                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.9, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        builder: (context, scale, child) =>
                            Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(14)),
                                  color: Color(0xffffffff),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  // left-align text & row
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(14),
                                        ),
                                        color: Colors.black,
                                      ),
                                      width: double.infinity,
                                      height: 60,
                                      alignment: Alignment.centerLeft,
                                      child: const Text(
                                        "Leisure Comfort",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(12),
                                      ),
                                      child: Image.asset(
                                        "assets/images/car1.jpg",
                                        width: double.infinity,
                                        height: 250,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text("For Group of Up to 4"),
                                    const SizedBox(height: 10),

                                    // ✅ Location row
                                    Row(
                                      children: const [
                                        Icon(Icons.location_on, size: 14,
                                            color: Colors.red),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "Atlanta Georgia USA",
                                            style: TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(context,
                                              MaterialPageRoute(builder: (c) =>
                                                  RideRequestPage()));
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: gold),
                                        child: const Text("Book a Ride",
                                          style: TextStyle(
                                              color: Colors.white),),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),


                      SizedBox(height: 30,),


                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.9, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        builder: (context, scale, child) =>
                            Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(14)),
                                  color: Color(0xffffffff),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  // left-align text & row
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(14),
                                        ),
                                        color: Colors.black,
                                      ),
                                      width: double.infinity,
                                      height: 60,
                                      alignment: Alignment.centerLeft,
                                      child: const Text(
                                        "Leisure Comfort",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(12),
                                      ),
                                      child: Image.asset(
                                        "assets/images/car1.jpg",
                                        width: double.infinity,
                                        height: 250,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text("For Group of Up to 4"),
                                    const SizedBox(height: 10),

                                    // ✅ Location row
                                    Row(
                                      children: const [
                                        Icon(Icons.location_on, size: 14,
                                            color: Colors.red),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            "Atlanta Georgia USA",
                                            style: TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(context,
                                              MaterialPageRoute(builder: (c) =>
                                                  RideRequestPage()));
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: gold),
                                        child: const Text("Book a Ride",
                                          style: TextStyle(
                                              color: Colors.white),),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ),


                      SizedBox(height: 50,),
                      Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: Column(
                            children: [
                              Center(
                                child: Text("FEATURED SERVICES",
                                  style: TextStyle(fontSize: 30,
                                      fontWeight: FontWeight.bold),),

                              ),
                              SizedBox(height: 30,),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Airport", textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 25)),
                                  SizedBox(height: 10,),
                                  Center(
                                    child: Text(
                                      "We serve all local airports, large and small,one-way or round-trip. Curbside or meet and greet we have you covered! Rates will vary, but you will find they are competitively priced, FBO options are also available",
                                      textAlign: TextAlign.center,)
                                    ,
                                  )
                                ],
                              ),
                              SizedBox(height: 30,),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Center(
                                    child: Text("Chartered Hourly",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 25)),
                                  ),

                                  SizedBox(height: 10,),
                                  Center(
                                    child: Text(
                                      "We are available for any events. Weddings, Business Meetings, Concerts or just a night on the town, we can customize our service based on your plans",
                                      textAlign: TextAlign.center,)
                                    ,
                                  )
                                ],
                              ),
                              SizedBox(height: 30,),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [

                                  Text("Chartered Transfer",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 25)),
                                  SizedBox(height: 10,),
                                  Text(
                                    "We don't want you to pay for hourly service that you don't require. Book your one-way or round-trip travel and receive your best-valued trip.",
                                    textAlign: TextAlign.center,)
                                ],
                              ),
                              SizedBox(height: 3,),
                              Row(),
                              SizedBox(height: 30,),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text("We want to hear from you!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 25)),
                                  SizedBox(),
                                  Text(
                                    "New to ride sharing, and want to know how it works? Have any question on how we help drivers and riders connet? We're here to help!",
                                    textAlign: TextAlign.center,)
                                ],
                              ),
                              SizedBox(height: 30,),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text("Why Leisure Ryde?",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 25, color: gold)),
                                  SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceEvenly,
                                    children: [
                                      Expanded(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.6, end: 1),
                                          duration: const Duration(
                                              milliseconds: 600),
                                          curve: Curves.easeOut,
                                          builder: (context, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize
                                                      .min,
                                                  children: const [
                                                    Icon(Icons.local_taxi,
                                                        size: 40,
                                                        color: Colors.black87),
                                                    SizedBox(height: 6),
                                                    Text("Better Service",
                                                        textAlign: TextAlign
                                                            .center),
                                                  ],
                                                ),
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.6, end: 1),
                                          duration: const Duration(
                                              milliseconds: 800),
                                          curve: Curves.easeOut,
                                          builder: (context, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize
                                                      .min,
                                                  children: const [
                                                    Icon(Icons.memory, size: 40,
                                                        color: Colors.black87),
                                                    SizedBox(height: 6),
                                                    Text("Top Technology",
                                                        textAlign: TextAlign
                                                            .center),
                                                  ],
                                                ),
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.6, end: 1),
                                          duration: const Duration(
                                              milliseconds: 1000),
                                          curve: Curves.easeOut,
                                          builder: (context, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize
                                                      .min,
                                                  children: const [
                                                    Icon(Icons.chair_alt,
                                                        size: 40,
                                                        color: Colors.black87),
                                                    SizedBox(height: 6),
                                                    Text("Luxury Delivery",
                                                        textAlign: TextAlign
                                                            .center),
                                                  ],
                                                ),
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.6, end: 1),
                                          duration: const Duration(
                                              milliseconds: 1200),
                                          curve: Curves.easeOut,
                                          builder: (context, scale, child) =>
                                              Transform.scale(
                                                scale: scale,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize
                                                      .min,
                                                  children: const [
                                                    Icon(
                                                        Icons.star_rate_rounded,
                                                        size: 40,
                                                        color: Colors.black87),
                                                    SizedBox(height: 6),
                                                    Text("Better Exclusivity",
                                                        textAlign: TextAlign
                                                            .center),
                                                  ],
                                                ),
                                              ),
                                        ),
                                      ),
                                    ],
                                  )


                                ],
                              ),
                            ],
                          )
                      ),

                      SizedBox(height: 30,),
                      Container(
                        padding: EdgeInsets.all(10),
                        color: black,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text("Save time and money",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 25, color: gold)),
                            SizedBox(height: 10),
                            Text(
                              "Avoid Wasting time renting multiple cars that don't suit your needs or paying more than you should. With leisure, you save time and money by always getting the best experience at the best price.",
                              style: TextStyle(color: Colors.white),)
                          ],
                        ),
                      ),

                      SizedBox(
                        height: 300,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Image.asset(
                              'assets/images/map.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),


                    ],
                  )

              ),
            );
          }

      ),

      bottomNavigationBar: ButtomNav(),
    );
  }
}
