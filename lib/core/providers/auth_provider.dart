import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'firebase_provider.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Server client ID from google-services.json
    serverClientId: '1057695268657-cir3ahv7d3h738ui3gjmn50tmblb8gu8.apps.googleusercontent.com',
    scopes: <String>[
      'email',
      'profile',
    ],
  );
  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  
  // Constructor to initialize the auth state
  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
      
      if (user != null) {
        _fetchUserModel();
      }
    });
  }
  
  // Fetch user model data from Firestore
  Future<void> _fetchUserModel() async {
    if (_currentUser == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      _userModel = await _firebaseService.getUserById(_currentUser!.uid);
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Initialize with FirebaseService
  late final FirebaseService _firebaseService;
  
  void initialize(firebaseProvider) {
    if (firebaseProvider is FirebaseService) {
      _firebaseService = firebaseProvider;
    } else if (firebaseProvider is FirebaseProvider) {
      _firebaseService = firebaseProvider.service;
    } else {
      throw ArgumentError('firebaseProvider must be either FirebaseService or FirebaseProvider');
    }
    
    if (_currentUser != null) {
      _fetchUserModel();
    }
  }
  
  // Sign in with email and password
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _currentUser = result.user;
      await _fetchUserModel();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Register with email and password
  Future<bool> registerWithEmailAndPassword(String email, String password, String name, String userType) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _currentUser = result.user;
      
      // Create user profile in Firestore
      final UserModel newUser = UserModel(
        id: _currentUser!.uid,
        name: name,
        email: email,
        role: userType == 'doctor' ? UserRole.doctor : UserRole.patient,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      
      await _firebaseService.createUser(newUser);
      _userModel = newUser;
      
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Check if a user exists in Firestore
  Future<bool> userExists(String uid) async {
    final user = await _firebaseService.getUserById(uid);
    return user != null;
  }
  
  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
      // First clear any existing sessions
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint("No existing Google session to sign out: $e");
      }
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn().catchError((error) {
        debugPrint("Error during Google Sign-In: $error");
        _error = "Google Sign-In failed: ${error.toString()}";
        _isLoading = false;
        notifyListeners();
        return null;
      });
      
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication.catchError((error) {
        debugPrint("Error getting Google authentication: $error");
        _error = "Failed to get Google authentication: ${error.toString()}";
        _isLoading = false;
        notifyListeners();
        return null;
      });
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        _error = "Google authentication tokens are missing";
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential result = await _auth.signInWithCredential(credential).catchError((error) {
        debugPrint("Firebase Auth sign-in failed: $error");
        _error = "Firebase authentication failed: ${error.toString()}";
        _isLoading = false;
        notifyListeners();
        return null;
      });
      
      if (result.user == null) {
        _error = "Failed to get user from Firebase";
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      _currentUser = result.user;
      
      // Check if the user exists in Firestore
      bool userExists = await this.userExists(_currentUser!.uid);
      
      if (!userExists) {
        // Create a new user profile
        final UserModel newUser = UserModel(
          id: _currentUser!.uid,
          name: _currentUser!.displayName ?? '',
          email: _currentUser!.email!,
          role: UserRole.patient, // Default role for Google sign-in
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );
        
        await _firebaseService.createUser(newUser);
        _userModel = newUser;
      } else {
        await _fetchUserModel();
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      _userModel = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  // Update user profile
  Future<bool> updateUserProfile(UserModel updatedUser) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _firebaseService.updateUser(updatedUser);
      _userModel = updatedUser;
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 