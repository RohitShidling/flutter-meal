import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:meal_app/core/network/dio_client.dart';
import 'package:meal_app/features/home/providers/menu_provider.dart';
import 'package:meal_app/core/storage/secure_storage.dart';
import 'package:meal_app/features/auth/data/repositories/auth_repository.dart';
import 'package:meal_app/features/auth/providers/auth_provider.dart';
import 'package:meal_app/features/auth/ui/screens/login_screen.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/features/home/ui/screens/home_screen.dart';
import 'package:meal_app/core/network/lookup_repository.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/features/children/data/repositories/children_repository.dart';
import 'package:meal_app/features/children/providers/children_provider.dart';
import 'package:meal_app/features/profile/data/repositories/profile_repository.dart';
import 'package:meal_app/features/profile/providers/profile_provider.dart';
import 'package:meal_app/core/providers/theme_provider.dart';
import 'package:meal_app/core/network/subscription_repository.dart';
import 'package:meal_app/core/providers/subscription_provider.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/features/home/data/repositories/homepage_repository.dart';
import 'package:meal_app/features/home/providers/homepage_provider.dart';
import 'package:meal_app/core/network/cart_repository.dart';
import 'package:meal_app/core/providers/cart_provider.dart';
import 'package:meal_app/core/network/meal_repository.dart';
import 'package:meal_app/core/providers/meal_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dependency Injection
    final secureStorage = SecureStorage();
    final dioClient = DioClient(secureStorage);
    final authRepository = AuthRepository(dioClient, secureStorage);
    final lookupRepository = LookupRepository(dioClient);
    final childrenRepository = ChildrenRepository(dioClient);
    final profileRepository = ProfileRepository(dioClient);
    final paymentRepository = PaymentRepository(dioClient);
    final homepageRepository = HomepageRepository(dioClient);
    final cartRepository = CartRepository(dioClient);
    final mealRepository = MealRepository(dioClient);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository)),
        ChangeNotifierProvider(create: (_) => LookupProvider(lookupRepository)),
        ChangeNotifierProvider(create: (_) => ChildrenProvider(childrenRepository)),
        ChangeNotifierProvider(create: (_) => ProfileProvider(profileRepository)),
        ChangeNotifierProvider(create: (_) => ThemeProvider(secureStorage)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(SubscriptionRepository(dioClient))),
        ChangeNotifierProvider(create: (_) => MenuProvider(dioClient)),
        ChangeNotifierProvider(create: (_) => PaymentProvider(paymentRepository)),
        ChangeNotifierProvider(create: (_) => HomepageProvider(homepageRepository)),
        ChangeNotifierProvider(create: (_) => CartProvider(cartRepository)),
        ChangeNotifierProvider(create: (_) => MealProvider(mealRepository)),
      ],
      child: const MainApp(),
    );
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buuttii',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: context.watch<ThemeProvider>().themeMode,
      home: const AuthWrapper(),
    );
  }
}


class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthProvider>().state;

    switch (authState) {
      case AuthState.initial:
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        );
      case AuthState.authenticated:
        return const HomeScreen();
      case AuthState.loading:
      case AuthState.unauthenticated:
      case AuthState.error:
        return const LoginScreen();
    }
  }
}
