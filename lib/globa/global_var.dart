import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'dart:io' show Platform;

const _androidKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY_ANDROID');
const _iosKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY_IOS');

final String googleMapKey = Platform.isAndroid ? _androidKey : _iosKey;




const CameraPosition googlePlexInitialPosition = CameraPosition(
  target: LatLng(-25.274398, 133.775136),
  zoom: 14.4746,
);

/*

StreamBuilder<User?>(
stream: FirebaseAuth.instance.authStateChanges(),
builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none ) {
return const EntryPage();
}

if (snapshot.hasData) {
return const HomePage();
} else {
return EntryPage();
}
},
),*/