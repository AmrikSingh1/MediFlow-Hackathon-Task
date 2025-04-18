import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:medi_connect/core/providers/firebase_provider.dart';
import 'package:medi_connect/core/providers/auth_provider.dart';
import 'package:medi_connect/core/providers/appointments_provider.dart';
import 'package:medi_connect/core/providers/ratings_provider.dart';

// Riverpod providers
final firebaseServiceProvider = riverpod.Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final authServiceProvider = riverpod.Provider<AuthService>((ref) {
  return AuthService();
});

// Provider for shared preferences
final sharedPreferencesProvider = riverpod.Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  runApp(
    MultiProvider(
      providers: [
        // Provider for Firebase service
        ChangeNotifierProvider(
          create: (_) => FirebaseProvider(),
        ),
        // Provider for Auth service
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = AuthProvider();
            final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
            authProvider.initialize(firebaseProvider);
            return authProvider;
          },
          lazy: false,
        ),
        // Provider for Appointments
        ChangeNotifierProvider(
          create: (context) {
            final appointmentsProvider = AppointmentsProvider();
            // Initialize with dependencies after the providers are created
            Future.microtask(() {
              final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              appointmentsProvider.initialize(firebaseProvider, authProvider);
            });
            return appointmentsProvider;
          },
        ),
        // Provider for Ratings
        ChangeNotifierProvider(
          create: (context) {
            final ratingsProvider = RatingsProvider();
            // Initialize with dependencies after the providers are created
            Future.microtask(() {
              final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              ratingsProvider.initialize(firebaseProvider, authProvider);
            });
            return ratingsProvider;
          },
        ),
      ],
      child: riverpod.ProviderScope(
        overrides: [
          // Provide shared preferences instance
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MediConnectApp(),
      ),
    ),
  );
}

class MediConnectApp extends riverpod.ConsumerWidget {
  const MediConnectApp({super.key});

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    return MaterialApp(
      title: 'MediConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          background: AppColors.background,
          surface: AppColors.surfaceLight,
          error: AppColors.error,
        ),
        fontFamily: AppTypography.fontFamily,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceLight,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: AppTypography.headlineSmall,
        ),
        scaffoldBackgroundColor: AppColors.background,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textLight,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: AppTypography.buttonLarge,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.surfaceDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.surfaceDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: Routes.splash,
    );
  }
}
