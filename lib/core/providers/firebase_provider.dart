import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class FirebaseProvider extends ChangeNotifier {
  late final FirebaseService _service;
  
  FirebaseProvider() {
    _service = FirebaseService();
  }
  
  // Getter for the service
  FirebaseService get service => _service;
  
  // Initialize any listeners or additional setup
  void initialize() {
    // Add any additional initialization logic here
  }
} 