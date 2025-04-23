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
import 'package:medi_connect/core/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

// Mock implementations for when Firebase is not available
class MockFirebaseService implements FirebaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    print("MockFirebaseService: Method ${invocation.memberName} was called with arguments ${invocation.positionalArguments}");
    if (invocation.isGetter && invocation.memberName.toString().contains('instance')) {
      return this;
    }
    
    if (invocation.isMethod) {
      // For Future methods, return a completed future
      if (invocation.memberName.toString().contains('get') || 
          invocation.memberName.toString().contains('fetch') ||
          invocation.memberName.toString().contains('create') ||
          invocation.memberName.toString().contains('update') ||
          invocation.memberName.toString().contains('delete')) {
        return Future.value(null);
      }
    }
    
    return null;
  }
  
  // Implement the most commonly used methods with mock data
  Future<UserModel?> getUserById(String userId) async {
    return UserModel(
      id: "mock_user_id",
      name: "Mock User",
      email: "mock@example.com",
      role: UserRole.patient,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }
  
  Future<void> createUser(UserModel user, {Map<String, dynamic>? additionalInfo}) async {
    print("MockFirebaseService: Creating user with ID ${user.id}");
    return;
  }
  
  Future<void> updateUser(UserModel user) async {
    print("MockFirebaseService: Updating user with ID ${user.id}");
    return;
  }
}

class MockFirebaseProvider extends FirebaseProvider {
  final MockFirebaseService _mockService = MockFirebaseService();
  
  @override
  FirebaseService get service => _mockService;
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  bool _isLoading = false;
  String? _error;
  final UserModel _mockUser = UserModel(
    id: "mock_user_id",
    name: "Mock User",
    email: "mock@example.com",
    role: UserRole.patient,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  );
  
  @override
  bool get isAuthenticated => true; // Always authenticated for testing
  
  @override
  bool get isLoading => _isLoading;
  
  @override
  String? get error => _error;
  
  @override
  get currentUser => null;
  
  @override
  get userModel => _mockUser;
  
  @override
  void initialize(provider) {
    print("MockAuthProvider: Initialized");
  }
  
  @override
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    await Future.delayed(Duration(seconds: 1)); // simulate network
    
    _isLoading = false;
    notifyListeners();
    return true;
  }
  
  @override
  Future<bool> registerWithEmailAndPassword(String email, String password, String name, String userType) async {
    _isLoading = true;
    notifyListeners();
    
    await Future.delayed(Duration(seconds: 1)); // simulate network
    
    _isLoading = false;
    notifyListeners();
    return true;
  }
  
  @override
  Future<bool> signInWithApple() async {
    _isLoading = true;
    notifyListeners();
    
    await Future.delayed(Duration(seconds: 1)); // simulate network
    
    _isLoading = false;
    notifyListeners();
    return true;
  }

  @override
  Future<void> signOut() async {
    // No-op for mock
  }
  
  @override
  Future<bool> userExists(String uid) async {
    return true;
  }
  
  @override
  Future<bool> updateUserProfile(UserModel updatedUser) async {
    print("MockAuthProvider: Updating user profile");
    return true;
  }

  @override
  noSuchMethod(Invocation invocation) {
    print("MockAuthProvider: Method ${invocation.memberName} was called");
    return super.noSuchMethod(invocation);
  }
}

// Mock appointments provider
class MockAppointmentsProvider extends ChangeNotifier {
  void initialize(provider, authProvider) {
    print("MockAppointmentsProvider: Initialized");
  }
}

// Mock ratings provider
class MockRatingsProvider extends ChangeNotifier {
  void initialize(provider, authProvider) {
    print("MockRatingsProvider: Initialized");
  }
}

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
  
  // Load environment variables first
  await dotenv.load(fileName: ".env");
  
  // Initialize shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();
  
  // Flag to track if Firebase is available
  bool isFirebaseAvailable = false;
  
  // Initialize Firebase with proper options and error handling
  try {
    // For iOS, we need to specify some options to handle the bundle ID mismatch
    FirebaseOptions? options;
    
    if (Platform.isIOS) {
      options = const FirebaseOptions(
        apiKey: 'AIzaSyBoFg8_KfYnIQl_-U6uPONejU0PfXKBiqM',
        appId: '1:494610997488:ios:21e7fd53469be2bfaba235',
        messagingSenderId: '494610997488',
        projectId: 'mediconnect-a8ac5',
        storageBucket: 'mediconnect-a8ac5.firebasestorage.app',
        // Override the iOS bundle ID to match the one in GoogleService-Info.plist
        iosBundleId: 'com.example.mediflowconnect',
      );
    }
    
    await Firebase.initializeApp(options: options);
    print("Firebase initialized successfully");
    isFirebaseAvailable = true;
  } catch (e) {
    print("Error initializing Firebase: $e");
    isFirebaseAvailable = false;
  }
  
  runApp(
    MultiProvider(
      providers: [
        // Provider for Firebase service
        ChangeNotifierProvider(
          create: (_) => isFirebaseAvailable ? FirebaseProvider() : MockFirebaseProvider(),
        ),
        // Provider for Auth service
        ChangeNotifierProvider<AuthProvider>(
          create: (context) {
            if (isFirebaseAvailable) {
              try {
                final authProvider = AuthProvider();
                final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
                authProvider.initialize(firebaseProvider);
                return authProvider;
              } catch (e) {
                print("Error initializing AuthProvider: $e");
                return MockAuthProvider();
              }
            } else {
              return MockAuthProvider();
            }
          },
          lazy: false,
        ),
        // Provider for Appointments
        ChangeNotifierProvider(
          create: (context) {
            if (isFirebaseAvailable) {
              final appointmentsProvider = AppointmentsProvider();
              // Initialize with dependencies after the providers are created
              Future.microtask(() {
                try {
                  final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  appointmentsProvider.initialize(firebaseProvider, authProvider);
                } catch (e) {
                  print("Error initializing AppointmentsProvider: $e");
                }
              });
              return appointmentsProvider;
            } else {
              return MockAppointmentsProvider();
            }
          },
        ),
        // Provider for Ratings
        ChangeNotifierProvider(
          create: (context) {
            if (isFirebaseAvailable) {
              final ratingsProvider = RatingsProvider();
              // Initialize with dependencies after the providers are created
              Future.microtask(() {
                try {
                  final firebaseProvider = Provider.of<FirebaseProvider>(context, listen: false);
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  ratingsProvider.initialize(firebaseProvider, authProvider);
                } catch (e) {
                  print("Error initializing RatingsProvider: $e");
                }
              });
              return ratingsProvider;
            } else {
              return MockRatingsProvider();
            }
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
