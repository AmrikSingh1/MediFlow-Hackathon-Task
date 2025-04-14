import 'package:flutter_test/flutter_test.dart';
import 'package:medi_connect/core/services/ai_service.dart';

void main() {
  group('AIService tests', () {
    test('AIService can be instantiated', () {
      // This is a basic smoke test to make sure we can instantiate the service
      final aiService = AIService();
      expect(aiService, isNotNull);
    });
  });
} 