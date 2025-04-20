import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'profile',
    ],
  );
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
  
  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      debugPrint("===== STARTING GOOGLE SIGN-IN PROCESS =====");
      debugPrint("Current platform: ${defaultTargetPlatform.toString()}");
      
      // First try to clear any existing sign-in sessions
      try {
        await _googleSignIn.signOut();
        debugPrint("✓ Successfully signed out any existing Google sessions");
      } catch (e) {
        debugPrint("! No existing Google session to sign out: $e");
      }
      
      // 1. Google Sign-In with better error handling
      debugPrint("1. Attempting to get GoogleSignInAccount...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn()
          .timeout(
            const Duration(minutes: 1),
            onTimeout: () {
              debugPrint("! Google Sign-In timed out after 1 minute");
              throw FirebaseAuthException(
                code: 'ERROR_SIGN_IN_TIMEOUT',
                message: 'Google Sign-In timed out. Please try again.',
              );
            },
          )
          .catchError((error) {
            debugPrint("! Error during Google Sign-In: $error");
            if (error.toString().contains('network')) {
              throw FirebaseAuthException(
                code: 'ERROR_NETWORK_REQUEST_FAILED',
                message: 'Network error during sign in. Please check your connection.',
              );
            }
            throw FirebaseAuthException(
              code: 'ERROR_GOOGLE_SIGN_IN_FAILED',
              message: 'Google Sign-In failed: ${error.toString()}',
            );
          });
      
      if (googleUser == null) {
        debugPrint("! Sign-in aborted: User canceled the sign-in process");
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }
      
      debugPrint("✓ Google Sign-In successful for: ${googleUser.email}");
      debugPrint("  User ID: ${googleUser.id}");
      debugPrint("  Display name: ${googleUser.displayName}");
      
      // 2. Get authentication credentials with better error handling
      debugPrint("2. Getting Google authentication tokens...");
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint("! Authentication token request timed out");
              throw FirebaseAuthException(
                code: 'ERROR_AUTH_TOKEN_TIMEOUT',
                message: 'Authentication token request timed out. Please try again.',
              );
            },
          )
          .catchError((error) {
            debugPrint("! Error getting Google authentication: $error");
            throw FirebaseAuthException(
              code: 'ERROR_GOOGLE_AUTH_FAILED',
              message: 'Failed to get Google authentication: ${error.toString()}',
            );
          });
      
      debugPrint("  Received authentication tokens:");
      debugPrint("  Access token exists: ${googleAuth.accessToken != null}");
      debugPrint("  ID token exists: ${googleAuth.idToken != null}");
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint("! Google Auth tokens are null");
        throw FirebaseAuthException(
          code: 'ERROR_MISSING_GOOGLE_AUTH_TOKEN',
          message: 'Google authentication tokens are missing',
        );
      }
      
      // Create the credential
      debugPrint("3. Creating Firebase credential with Google tokens...");
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // 3. Sign in to Firebase with credentials
      debugPrint("4. Signing in to Firebase with Google credentials...");
      final userCredential = await _auth.signInWithCredential(credential)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint("! Firebase sign-in timed out");
              throw FirebaseAuthException(
                code: 'ERROR_FIREBASE_TIMEOUT',
                message: 'Firebase authentication timed out. Please try again.',
              );
            },
          )
          .catchError((error) {
            debugPrint("! Firebase Auth sign-in failed: $error");
            
            // Handle specific Firebase auth errors
            if (error is FirebaseAuthException) {
              switch (error.code) {
                case 'account-exists-with-different-credential':
                  debugPrint("! Account exists with different credential");
                  throw FirebaseAuthException(
                    code: error.code,
                    message: 'An account already exists with the same email. Try another sign-in method.',
                  );
                case 'invalid-credential':
                  debugPrint("! Invalid credential");
                  throw FirebaseAuthException(
                    code: error.code,
                    message: 'The authentication credential is invalid. Please try again.',
                  );
                default:
                  throw error;
              }
            }
            
            throw FirebaseAuthException(
              code: 'ERROR_FIREBASE_AUTH_FAILED',
              message: 'Firebase authentication failed: ${error.toString()}',
            );
          });
      
      if (userCredential.user == null) {
        debugPrint("! No user returned from Firebase Auth");
        throw FirebaseAuthException(
          code: 'ERROR_NULL_USER',
          message: 'No user returned from authentication. Please try again.',
        );
      }
      
      debugPrint("✓ Firebase Auth credential successful. User ID: ${userCredential.user?.uid}");
      
      // 4. Check if user exists in Firestore
      debugPrint("5. Checking if user exists in Firestore...");
      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Direct confirmation that the user is in Firebase Auth
        try {
          final tokenResult = await user.getIdTokenResult(true);
          debugPrint("✓ User ID token validated: ${tokenResult.token != null}");
        } catch (e) {
          debugPrint("! Error getting ID token: $e");
        }
        
        // 5. Check if user exists in Firestore
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
      
      debugPrint("===== GOOGLE SIGN-IN PROCESS COMPLETED =====");
      return userCredential;
    } catch (e) {
      debugPrint("! ERROR in Google Sign-In: $e");
      rethrow;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
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