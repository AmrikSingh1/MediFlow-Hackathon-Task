import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
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
    UserRole role
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user in Firestore
      if (userCredential.user != null) {
        final user = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          role: role,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );
        
        await _firebaseService.createUser(user);
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
      debugPrint("Starting Google Sign-In process...");
      
      // 1. Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("Sign-in aborted: User canceled the sign-in process");
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }
      
      debugPrint("Google Sign-In successful for: ${googleUser.email}");
      
      // 2. Get authentication credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // 3. Sign in to Firebase with credentials
      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint("Firebase Auth credential successful. User ID: ${userCredential.user?.uid}");
      
      // 4. Work with the authenticated user
      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Direct confirmation that the user is in Firebase Auth
        final tokenResult = await user.getIdTokenResult(true);
        debugPrint("User ID token validated: ${tokenResult.token != null}");
        
        // 5. Check if user exists in Firestore
        final existingUser = await _firebaseService.getUserById(user.uid);
        
        if (existingUser == null) {
          debugPrint("Creating new user in Firestore");
          // Create new user
          final newUser = UserModel(
            id: user.uid,
            name: user.displayName ?? 'User',
            email: user.email ?? '',
            role: UserRole.patient, // Default to patient for Google sign-in
            profileImageUrl: user.photoURL,
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          );
          
          try {
            // 6a. Create user in Firestore
            await _firebaseService.createUser(newUser);
            debugPrint("Successfully created user in Firestore");
            _userModel = newUser;
          } catch (e) {
            debugPrint("Error creating user in Firestore: $e");
            // Try a direct approach
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set(newUser.toMap());
            debugPrint("Second attempt to create user completed");
            _userModel = newUser;
          }
        } else {
          debugPrint("User already exists in Firestore, updating last login");
          // Update existing user
          final updatedUser = existingUser.copyWith(
            updatedAt: Timestamp.now(),
            name: user.displayName ?? existingUser.name,
            profileImageUrl: user.photoURL ?? existingUser.profileImageUrl,
          );
          
          try {
            await _firebaseService.updateUser(updatedUser);
            debugPrint("Successfully updated user in Firestore");
            _userModel = updatedUser;
          } catch (e) {
            debugPrint("Error updating user in Firestore: $e");
          }
        }
        
        notifyListeners();
      } else {
        debugPrint("Warning: No user returned from Firebase Auth");
      }
      
      return userCredential;
    } catch (e) {
      debugPrint("Error in Google Sign-In: $e");
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
      return _userModel!.medicalInfo != null && 
             _userModel!.phoneNumber != null && 
             _userModel!.phoneNumber!.isNotEmpty;
    }
    
    // For doctors, check if they have specialty and phone number
    if (_userModel!.role == UserRole.doctor) {
      return _userModel!.phoneNumber != null && 
             _userModel!.phoneNumber!.isNotEmpty;
    }
    
    return false;
  }
} 