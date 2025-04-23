import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'firebase_provider.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
  Future<bool> signInWithApple() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      
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
      ).catchError((error) {
        debugPrint("Error during Apple Sign-In: $error");
        _error = "Apple Sign-In failed: ${error.toString()}";
        _isLoading = false;
        notifyListeners();
        return null;
      });
      
      if (appleCredential == null || appleCredential.identityToken == null) {
        _error = "Apple authentication tokens are missing";
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Create an OAuthCredential from the credential returned by Apple.
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce,
      );
      
      final UserCredential result = await _auth.signInWithCredential(oauthCredential).catchError((error) {
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
      
      // If the user doesn't have a display name but we got one from Apple
      if (_currentUser?.displayName == null || _currentUser!.displayName!.isEmpty) {
        if (appleCredential.givenName != null && appleCredential.familyName != null) {
          await _currentUser!.updateDisplayName(
            '${appleCredential.givenName} ${appleCredential.familyName}'
          );
        }
      }
      
      // Check if the user exists in Firestore
      bool userExists = await this.userExists(_currentUser!.uid);
      
      if (!userExists) {
        // Create a new user profile
        final UserModel newUser = UserModel(
          id: _currentUser!.uid,
          name: _currentUser!.displayName ?? '',
          email: _currentUser!.email ?? '',
          role: UserRole.patient, // Default role for Apple sign-in
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