import 'package:flutter/material.dart';
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
import 'package:meal_app/core/providers/session_provider.dart';
import 'package:meal_app/core/services/network_status_service.dart';
import 'package:meal_app/core/widgets/offline_banner.dart';

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
    // The session provider is a long-lived singleton shared between the
    // network layer (to push expire events) and the UI (to react to them).
    final sessionProvider = SessionProvider();
    final dioClient = DioClient(secureStorage, sessionProvider: sessionProvider);
    final authRepository = AuthRepository(dioClient, secureStorage);
    final lookupRepository = LookupRepository(dioClient);
    final childrenRepository = ChildrenRepository(dioClient);
    final profileRepository = ProfileRepository(dioClient);
    final paymentRepository = PaymentRepository(dioClient);
    final homepageRepository = HomepageRepository(dioClient);
    final cartRepository = CartRepository(dioClient);
    final mealRepository = MealRepository(dioClient);

    // Start global online/offline monitor + attach Dio for queue replay.
    NetworkStatusService.instance.attachDioClient(dioClient);
    NetworkStatusService.instance.start();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sessionProvider),
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
      builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
      // navigatorKey lets us show messages from the network layer if needed.
      home: const AuthWrapper(),
    );
  }
}


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _logoutInFlight = false;
  SessionProvider? _sessionProvider;

  @override
  void initState() {
    super.initState();
    // Listen for session-expired events from the network layer.
    _sessionProvider = context.read<SessionProvider>();
    _sessionProvider?.addListener(_handleSessionChange);
  }

  @override
  void dispose() {
    _sessionProvider?.removeListener(_handleSessionChange);
    super.dispose();
  }

  /// When the network layer reports an expired session, force-logout and
  /// surface a clear message. This guarantees the user is always returned
  /// to the login screen with stale tokens cleared.
  Future<void> _handleSessionChange() async {
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    if (!session.isExpired || _logoutInFlight) return;
    _logoutInFlight = true;
    final reason = session.reason ?? 'Session expired. Please log in again.';
    try {
      await context.read<AuthProvider>().logout();
    } catch (_) {/* ignore */}
    if (!mounted) {
      _logoutInFlight = false;
      return;
    }
    session.acknowledge();
    _logoutInFlight = false;
    // Show a non-blocking notice on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(reason),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthProvider>().state;

    switch (authState) {
      case AuthState.initial:
        // Lightweight shell — never block on network; theme follows system.
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: const SizedBox.shrink(),
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

