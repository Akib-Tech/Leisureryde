// lib/app/service_locator.dart
import 'package:get_it/get_it.dart';

import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../viewmodel/theme_view_model.dart';
import 'app_theme.dart';

GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  var localStorageInstance = LocalStorageService();
  await localStorageInstance.init();
  locator.registerSingleton<LocalStorageService>(localStorageInstance);

  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => ThemeViewModel());

}