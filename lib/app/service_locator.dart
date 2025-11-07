// lib/app/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:leisureryde/services/chat_service.dart';
import 'package:leisureryde/services/payment_service.dart';
import 'package:leisureryde/viewmodel/payment/payment.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/directions_service.dart';
import '../services/fare_calculation_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import '../services/place_service.dart';
import '../services/ride_service.dart';
import '../services/storage_service.dart';
import '../viewmodel/theme_view_model.dart';
import 'app_theme.dart';

GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  var localStorageInstance = LocalStorageService();
  await localStorageInstance.init();
  locator.registerSingleton<LocalStorageService>(localStorageInstance);

  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => ThemeViewModel());
  locator.registerLazySingleton(() => DatabaseService());
  locator.registerLazySingleton(() => StorageService());
  locator.registerLazySingleton(() => LocationService());
  locator.registerLazySingleton(() => DirectionsService());
  locator.registerLazySingleton(() => RideService());
  locator.registerLazySingleton(() => PlacesService());
  locator.registerLazySingleton(() => FareCalculationService());

  locator.registerLazySingleton(() => PaymentService());
  locator.registerLazySingleton(() => PaymentViewModel());

  locator.registerLazySingleton(() => ChatService());



}