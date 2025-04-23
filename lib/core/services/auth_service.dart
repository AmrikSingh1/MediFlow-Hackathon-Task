import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  UserModel? _userModel;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Get current user model
  UserModel? get userModel => _userModel;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Constructor to initialize auth state listener
  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _loadUserData();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }
  
  // Load user data from Firestore
  Future<void> _loadUserData() async {
    if (currentUser != null) {
      _userModel = await _firebaseService.getUserById(currentUser!.uid);
      notifyListeners();
    }
  }
  
  // Get current Firebase user
  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }
  
  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _loadUserData();
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email, 
    String password, 
    String name, 
    UserRole role,
    {String? specialty}
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user in Firestore
      if (userCredential.user != null) {
        final Map<String, dynamic>? additionalInfo = role == UserRole.doctor && specialty != null 
            ? {
                'specialty': specialty,
                'doctorInfo': {
                  'specialty': specialty,
                  'isAvailable': true,
                  'rating': 0.0,
                  'ratingCount': 0,
                  'experience': 0,
                }
              } 
            : null;
            
        final user = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          role: role,
          doctorInfo: role == UserRole.doctor && specialty != null ? {'specialty': specialty} : null,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );
        
        await _firebaseService.createUser(user, additionalInfo: additionalInfo);
        _userModel = user;
        notifyListeners();
      }
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Generates a cryptographically secure random nonce, to be included in a
  /// credential request.
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Sign in with Apple
  Future<UserCredential> signInWithApple() async {
    try {
      debugPrint("===== STARTING APPLE SIGN-IN PROCESS =====");
      debugPrint("Current platform: ${defaultTargetPlatform.toString()}");
      
      // Check if Apple Sign In is available (returns false on simulators)
      final bool isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        debugPrint("! Apple Sign In is not available on this device (likely a simulator)");
        throw FirebaseAuthException(
          code: 'ERROR_APPLE_SIGN_IN_NOT_AVAILABLE',
          message: 'Apple Sign In is not available on this device. Please use a physical device or another sign-in method.',
        );
      }
      
      // To prevent replay attacks with the credential returned from Apple, we
      // include a nonce in the credential request. When signing in with
      // Firebase, the nonce in the id token returned by Apple, is expected to
      // match the sha256 hash of `rawNonce`.
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Request credential for the currently signed in Apple account.
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      debugPrint("✓ Apple Sign-In successful");
      debugPrint("  Identity token exists: ${appleCredential.identityToken != null}");
      
      if (appleCredential.identityToken == null) {
        debugPrint("! Apple identity token is null");
        throw FirebaseAuthException(
          code: 'ERROR_MISSING_APPLE_AUTH_TOKEN',
          message: 'Apple authentication token is missing',
        );
      }

      // Create an OAuthCredential from the credential returned by Apple.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce,
      );

      debugPrint("3. Signing in to Firebase with Apple credentials...");
      // Sign in to Firebase with the Apple OAuthCredential.
      final userCredential = await _auth.signInWithCredential(oauthCredential)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint("! Firebase sign-in timed out");
              throw FirebaseAuthException(
                code: 'ERROR_FIREBASE_TIMEOUT',
                message: 'Firebase authentication timed out. Please try again.',
              );
            },
          );
          
      if (userCredential.user == null) {
        debugPrint("! No user returned from Firebase Auth");
        throw FirebaseAuthException(
          code: 'ERROR_NULL_USER',
          message: 'No user returned from authentication. Please try again.',
        );
      }
      
      debugPrint("✓ Firebase Auth credential successful. User ID: ${userCredential.user?.uid}");
      
      // If the user doesn't have a display name (subsequent sign-ins won't return name)
      // but we got one from Apple, update the Firebase user's display name
      if (userCredential.user?.displayName == null || 
          userCredential.user!.displayName!.isEmpty) {
        if (appleCredential.givenName != null && appleCredential.familyName != null) {
          await userCredential.user!.updateDisplayName(
            '${appleCredential.givenName} ${appleCredential.familyName}'
          );
        }
      }
      
      // Check if user exists in Firestore
      debugPrint("4. Checking if user exists in Firestore...");
      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Direct confirmation that the user is in Firebase Auth
        try {
          final tokenResult = await user.getIdTokenResult(true);
          debugPrint("✓ User ID token validated: ${tokenResult.token != null}");
        } catch (e) {
          debugPrint("! Error getting ID token: $e");
        }
        
        // Check if user exists in Firestore
        try {
          final existingUser = await _firebaseService.getUserById(user.uid);
          
          if (existingUser != null) {
            debugPrint("✓ User already exists in Firestore, updating last login");
            // Update existing user
            final updatedUser = existingUser.copyWith(
              updatedAt: Timestamp.now(),
              name: user.displayName ?? existingUser.name,
              profileImageUrl: user.photoURL ?? existingUser.profileImageUrl,
            );
            
            try {
              await _firebaseService.updateUser(updatedUser);
              debugPrint("✓ Successfully updated user in Firestore");
              _userModel = updatedUser;
              notifyListeners();
            } catch (e) {
              debugPrint("! Error updating user in Firestore: $e");
            }
          } else {
            // For new users, let the login page handle role selection and user creation
            debugPrint("! New user detected. Login page will handle role selection.");
          }
        } catch (e) {
          debugPrint("! Error checking user in Firestore: $e");
        }
      }
      
      // Check if Firebase is properly initialized
      try {
        final app = Firebase.app();
        debugPrint("✓ Firebase app is initialized: ${app.name}");
      } catch (e) {
        debugPrint("! Firebase is not properly initialized: $e");
        throw FirebaseAuthException(
          code: 'ERROR_FIREBASE_NOT_INITIALIZED',
          message: 'Firebase is not properly initialized. Please restart the app.',
        );
      }
      
      debugPrint("===== APPLE SIGN-IN PROCESS COMPLETED =====");
      return userCredential;
    } catch (e) {
      debugPrint("! ERROR in Apple Sign-In: $e");
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _userModel = null;
    notifyListeners();
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
  
  // Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    if (currentUser == null) return null;
    _userModel = await _firebaseService.getUserById(currentUser!.uid);
    notifyListeners();
    return _userModel;
  }
  
  // Update user profile
  Future<void> updateUserProfile(UserModel user) async {
    await _firebaseService.updateUser(user);
    _userModel = user;
    notifyListeners();
  }
  
  // Change password
  Future<void> changePassword(String newPassword) async {
    if (currentUser == null) throw Exception('No user logged in');
    await currentUser!.updatePassword(newPassword);
  }
  
  // Helper method to check if user profile is complete
  Future<bool> isUserProfileComplete() async {
    if (_userModel == null) {
      await _loadUserData();
    }
    
    // If user model is still null, user doesn't exist
    if (_userModel == null) return false;
    
    // For patients, check if they have medical info
    if (_userModel!.role == UserRole.patient) {
      final medicalInfo = _userModel!.medicalInfo;
      
      if (medicalInfo == null) return false;
      
      // Check essential fields in medicalInfo
      final hasPhoneNumber = _userModel!.phoneNumber != null && _userModel!.phoneNumber!.isNotEmpty;
      final hasDob = medicalInfo['dateOfBirth'] != null && medicalInfo['dateOfBirth'].isNotEmpty;
      final hasGender = medicalInfo['gender'] != null && medicalInfo['gender'].isNotEmpty;
      final hasHeight = medicalInfo['height'] != null;
      final hasWeight = medicalInfo['weight'] != null;
      final hasAddress = medicalInfo['address'] != null && medicalInfo['address'].isNotEmpty;
      
      return hasPhoneNumber && hasDob && hasGender && hasHeight && hasWeight && hasAddress;
    }
    
    // For doctors, check if they have specialty and phone number
    if (_userModel!.role == UserRole.doctor) {
      final hasPhoneNumber = _userModel!.phoneNumber != null && _userModel!.phoneNumber!.isNotEmpty;
      final hasSpecialty = _userModel!.medicalInfo != null && 
                          _userModel!.medicalInfo!['specialty'] != null && 
                          _userModel!.medicalInfo!['specialty'].isNotEmpty;
      
      return hasPhoneNumber && hasSpecialty;
    }
    
    return false;
  }
  
  // Update user role
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      // Get the current user data
      final user = await _firebaseService.getUserById(userId);
      
      if (user != null) {
        // Update the role
        final updatedUser = user.copyWith(
          role: role,
          updatedAt: Timestamp.now(),
        );
        
        // Save to Firestore
        await _firebaseService.updateUser(updatedUser);
        
        // Update local model
        _userModel = updatedUser;
        notifyListeners();
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }
  
  // Helper method to check if user is newly created
  bool isNewlyCreatedUser() {
    if (_userModel == null) return false;
    
    // Check if created and updated timestamps are very close (within 5 seconds)
    final createdAt = _userModel!.createdAt.toDate();
    final updatedAt = _userModel!.updatedAt.toDate();
    final difference = updatedAt.difference(createdAt).inSeconds;
    
    return difference < 5;
  }
} 