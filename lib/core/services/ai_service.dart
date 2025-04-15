import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

class AIService {
  final Dio _dio = Dio();
  
  // HuggingFace API endpoints
  final String _huggingFaceBaseUrl = 'https://api-inference.huggingface.co/models';
  
  // Using a more advanced model for better responses
  final String _chatModelId = 'mistralai/Mistral-7B-Instruct-v0.2';
  final String _whisperModelId = 'openai/whisper-large-v3';
  
  // API Key
  String get _huggingFaceApiKey => dotenv.env['HUGGINGFACE_API_KEY'] ?? '';
  
  // Test the API connection
  Future<bool> testConnection() async {
    try {
      final apiKey = _huggingFaceApiKey;
      if (apiKey.isEmpty) {
        debugPrint('AIService: API key is empty');
        return false;
      }
      
      debugPrint('AIService: Testing connection with API key: ${apiKey.substring(0, 4)}...');
      
      final response = await _dio.get(
        'https://api-inference.huggingface.co/status',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        debugPrint('AIService: Connection successful');
        return true;
      } else {
        debugPrint('AIService: Connection failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('AIService: Connection test failed with error: $e');
      return false;
    }
  }
  
  // Generate pre-anamnesis with HuggingFace
  Future<String> generatePreAnamnesis({
    required String patientDescription,
    required String symptoms,
    required List<String> previousConditions,
  }) async {
    try {
      debugPrint('AIService: Generating pre-anamnesis report');
      
      final prompt = '''
      <s>[INST] You are a medical assistant helping to generate a pre-anamnesis report.
      Your task is to analyze the patient's description, symptoms, and medical history
      to create a structured report that will be useful for a physician.
      Include potential diagnoses, recommended tests, and follow-up questions.
      Format the output in markdown with clear sections.
      
      Patient Description: $patientDescription
      Symptoms: $symptoms
      Previous Medical Conditions: ${previousConditions.join(', ')}
      Please generate a pre-anamnesis report. [/INST]</s>
      ''';
      
      final response = await _dio.post(
        '$_huggingFaceBaseUrl/$_chatModelId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_huggingFaceApiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode({
          'inputs': prompt,
          'parameters': {
            'max_new_tokens': 500,
            'temperature': 0.7,
            'top_p': 0.95,
            'do_sample': true,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('AIService: Pre-anamnesis report generated successfully');
        final result = response.data;
        final generatedText = result[0]['generated_text'] ?? '';
        
        // Extract only the response part (after the prompt)
        final cleanedResponse = _cleanResponse(prompt, generatedText);
        return cleanedResponse.isNotEmpty 
            ? cleanedResponse 
            : 'Sorry, I could not generate a pre-anamnesis report.';
      } else {
        debugPrint('AIService: Failed to generate pre-anamnesis: Status ${response.statusCode}');
        return 'Sorry, I could not generate a pre-anamnesis report due to a server error.';
      }
    } catch (e) {
      debugPrint('AIService: Exception generating pre-anamnesis: $e');
      return 'Sorry, I could not generate a pre-anamnesis report due to an error.';
    }
  }
  
  // Chat with AI for doctor-patient communication
  Future<String> generateResponse({
    required String prompt,
    required List<Map<String, String>> conversationHistory,
    String language = 'english', // Add language parameter with default value
  }) async {
    try {
      // Format conversation history to preserve context
      final formattedHistory = conversationHistory.map((message) {
        final role = message['role'] == 'user' ? 'User' : 'Assistant';
        return '$role: ${message['content']}';
      }).join('\n');
      
      debugPrint('AIService: Generating response for: "${prompt.substring(0, min(20, prompt.length))}..." in $language');
      
      // Detect if the prompt is in Hindi or Hinglish
      final containsHindi = _containsHindiCharacters(prompt);
      final isHinglish = _isHinglish(prompt);
      
      // Update language based on content detection
      if (containsHindi && language == 'english') {
        language = 'hindi';
      } else if (isHinglish && language == 'english') {
        language = 'hinglish';
      }
      
      // Get language specific instructions
      final languageInstructions = _getLanguageInstructions(language);
      
      final promptWithHistory = '''
      <s>[INST] You are MediConnect AI, an advanced health assistant designed to provide helpful, 
      accurate, and compassionate health information to users. 
      
      Your personality is friendly, empathetic, and conversational - respond like a thoughtful health professional
      having a real conversation, not like an automated system. Use natural language and conversational flow.
      
      $languageInstructions
      
      Your primary capabilities:
      1. Answer health questions with evidence-based information
      2. Explain medical terminology in simple terms
      3. Guide users on when to seek professional medical help
      4. Discuss general wellness, nutrition, and preventive health
      5. Respond with empathy to health concerns
      
      Guidelines:
      - Always clarify you are an AI assistant, not a healthcare professional
      - Do not give definitive diagnoses or prescribe specific medications
      - For serious symptoms, recommend seeing a healthcare provider
      - Personalize responses based on the user's specific question and conversation history
      - Acknowledge limitations rather than providing potentially incorrect information
      - Always respond directly to what the user is asking in this specific message
      
      Previous conversation:
      $formattedHistory
      
      User's message: $prompt [/INST]</s>
      ''';
      
      // Add retry mechanism
      int maxRetries = 3;
      int currentRetry = 0;
      
      while (currentRetry < maxRetries) {
        try {
          final response = await _dio.post(
            '$_huggingFaceBaseUrl/$_chatModelId',
            options: Options(
              headers: {
                'Authorization': 'Bearer $_huggingFaceApiKey',
                'Content-Type': 'application/json',
              },
              receiveTimeout: const Duration(seconds: 120), // Increase timeout
              sendTimeout: const Duration(seconds: 60),
            ),
            data: jsonEncode({
              'inputs': promptWithHistory,
              'parameters': {
                'max_new_tokens': 500,
                'temperature': 0.8, // Slightly higher for more creativity
                'top_p': 0.9,
                'do_sample': true,
              },
            }),
          );
          
          if (response.statusCode == 200) {
            final result = response.data;
            if (result == null || result.isEmpty) {
              debugPrint('AIService: Empty response received');
              currentRetry++;
              continue; // Try again
            }
            
            final generatedText = result[0]['generated_text'] ?? '';
            
            // Extract only the response part (after the prompt)
            final cleanedResponse = _cleanResponse(promptWithHistory, generatedText);
            
            debugPrint('AIService: Response generated successfully. Length: ${cleanedResponse.length}');
            
            if (cleanedResponse.isNotEmpty) {
              return cleanedResponse;
            } else {
              // If cleaning fails on the first try, retry
              if (currentRetry < maxRetries - 1) {
                currentRetry++;
                continue;
              }
              // Fallback if cleaning fails after all retries
              final fallbackResponse = _getLanguageFallbackResponse(language);
              debugPrint('AIService: Used fallback response after failed cleaning');
              return fallbackResponse;
            }
          } else {
            debugPrint('AIService: Failed with status ${response.statusCode}, retry ${currentRetry + 1}/$maxRetries');
            currentRetry++;
            
            // Add delay between retries
            await Future.delayed(Duration(seconds: 2));
            
            if (currentRetry >= maxRetries) {
              debugPrint('AIService: Max retries reached, returning error response');
              return _getLanguageErrorResponse(language);
            }
          }
        } catch (e) {
          debugPrint('AIService: Exception during retry $currentRetry: $e');
          currentRetry++;
          
          // Add delay between retries
          await Future.delayed(Duration(seconds: 2));
          
          if (currentRetry >= maxRetries) {
            debugPrint('AIService: Max retries reached after exceptions, returning error response');
            return _getLanguageErrorResponse(language);
          }
        }
      }
      
      // If we somehow get here, return error response
      return _getLanguageErrorResponse(language);
    } catch (e) {
      debugPrint('AIService: Exception generating response: $e');
      return _getLanguageErrorResponse(language);
    }
  }
  
  // Helper method to clean the AI response and extract only the reply part
  String _cleanResponse(String prompt, String fullResponse) {
    try {
      // Remove the prompt part from the response
      if (fullResponse.contains(prompt)) {
        final cleanedText = fullResponse.substring(fullResponse.indexOf(prompt) + prompt.length);
        return cleanedText.trim();
      }
      
      // Alternative cleaning method for Mistral format
      if (fullResponse.contains('[/INST]</s>')) {
        final parts = fullResponse.split('[/INST]</s>');
        if (parts.length > 1) {
          return parts[1].trim();
        }
      }
      
      // If prompt cleaning didn't work, return the text after the last [/INST] tag
      if (fullResponse.contains('[/INST]')) {
        final parts = fullResponse.split('[/INST]');
        if (parts.length > 1) {
          return parts.last.trim();
        }
      }
      
      // If no specific patterns work, remove the first chunk that might contain the prompt
      final lines = fullResponse.split('\n');
      if (lines.length > 3) {
        return lines.sublist(3).join('\n').trim();
      }
      
      return fullResponse;
    } catch (e) {
      debugPrint('AIService: Error cleaning response: $e');
      return fullResponse;
    }
  }
  
  // Utility to get the minimum of two numbers
  int min(int a, int b) => a < b ? a : b;
  
  // Transcribe audio using HuggingFace Whisper model
  Future<String> transcribeAudio(File audioFile) async {
    try {
      final response = await _dio.post(
        '$_huggingFaceBaseUrl/$_whisperModelId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_huggingFaceApiKey',
          },
        ),
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            audioFile.path,
            contentType: MediaType('audio', 'mp3'),
          ),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return data['text'] ?? '';
      } else {
        throw Exception('Failed to transcribe audio: ${response.data}');
      }
    } catch (e) {
      throw Exception('Failed to transcribe audio: $e');
    }
  }
  
  // Record audio and save to file
  Future<File> recordAudio() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
      
      // Note: In a real implementation, you'd use a Flutter audio recording package here
      // For example: flutter_sound, record, etc.
      // This is just a placeholder
      
      // Simulated recording file (this would normally be created by the recording library)
      final File file = File(filePath);
      if (!file.existsSync()) {
        file.createSync();
      }
      
      return file;
    } catch (e) {
      throw Exception('Failed to record audio: $e');
    }
  }
  
  // Generate treatment recommendations
  Future<String> generateTreatmentRecommendations(String preAnamnesis) async {
    try {
      final prompt = '''
      <s>[INST] You are a medical assistant helping doctors with treatment recommendations.
      Based on the pre-anamnesis report, suggest potential treatment approaches,
      medications, lifestyle changes, and follow-up care. Always emphasize that
      these are suggestions for the physician to consider, not direct medical advice.
      
      Pre-anamnesis report:
      $preAnamnesis
      
      Please provide treatment recommendations for the physician to consider. [/INST]</s>
      ''';
      
      final response = await _dio.post(
        '$_huggingFaceBaseUrl/$_chatModelId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_huggingFaceApiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode({
          'inputs': prompt,
          'parameters': {
            'max_new_tokens': 400,
            'temperature': 0.7,
            'top_p': 0.95,
            'do_sample': true,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final result = response.data;
        final generatedText = result[0]['generated_text'] ?? '';
        
        // Extract only the response part (after the prompt)
        final cleanedResponse = _cleanResponse(prompt, generatedText);
        return cleanedResponse.isNotEmpty 
            ? cleanedResponse 
            : 'Sorry, I could not generate treatment recommendations.';
      } else {
        return 'Sorry, I could not generate treatment recommendations due to a server error.';
      }
    } catch (e) {
      debugPrint('AIService: Exception generating treatment recommendations: $e');
      return 'Sorry, I could not generate treatment recommendations due to an error.';
    }
  }
  
  // Helper method to check if text contains Hindi characters
  bool _containsHindiCharacters(String text) {
    // Unicode range for Hindi: \u0900-\u097F
    final hindiRegex = RegExp(r'[\u0900-\u097F]');
    return hindiRegex.hasMatch(text);
  }
  
  // Helper method to check if text is Hinglish
  bool _isHinglish(String text) {
    // Check for common Hinglish patterns - English words with Hindi structure
    // or Hindi words written in English
    final hinglishIndicators = [
      'nahi', 'hai', 'kya', 'acha', 'thik', 'theek', 'haan', 'nahin', 
      'kaise', 'kaisa', 'kitna', 'kab', 'kyun', 'maine', 'mujhe', 'tumhe',
      'aap', 'tum', 'main', 'hamara', 'mera', 'tera', 'unka'
    ];
    
    final lowercaseText = text.toLowerCase();
    return hinglishIndicators.any((word) => lowercaseText.contains(word)) &&
        !_containsHindiCharacters(text); // Not pure Hindi
  }
  
  // Get language specific instructions
  String _getLanguageInstructions(String language) {
    switch (language) {
      case 'hindi':
        return '''
        LANGUAGE INSTRUCTIONS:
        - Respond entirely in Hindi, using Devanagari script.
        - Use simple, conversational Hindi.
        - When explaining medical terms, provide both the Hindi and English terms.
        - Be respectful and use appropriate formal address (आप).
        ''';
      case 'hinglish':
        return '''
        LANGUAGE INSTRUCTIONS:
        - Respond in Hinglish (mix of Hindi and English).
        - Use Roman script for Hindi words.
        - Use English for technical medical terms but explain them in Hinglish.
        - Match the user's style and ratio of Hindi to English.
        - Be conversational and casual.
        ''';
      default: // english
        return '''
        LANGUAGE INSTRUCTIONS:
        - Respond in clear, simple English.
        - Avoid complex medical jargon, or explain it when necessary.
        ''';
    }
  }
  
  // Get language specific fallback responses
  String _getLanguageFallbackResponse(String language) {
    switch (language) {
      case 'hindi':
        return "मुझे आपकी स्वास्थ्य से जुड़े सवालों का जवाब देने में खुशी होगी। याद रखें, मैं एक AI सहायक हूँ और किसी चिकित्सक का विकल्प नहीं हूँ। आपके विशिष्ट चिकित्सीय सलाह के लिए कृपया किसी डॉक्टर से परामर्श करें। मैं आपकी किस प्रकार सहायता कर सकता हूँ?";
      case 'hinglish':
        return "Aapke health question ka jawab dene mein mujhe khushi hogi. Yaad rakhein, main ek AI assistant hoon aur doctor ki jagah nahi le sakta. Specific medical advice ke liye, please kisi healthcare professional se consult karein. Main aapki kaise help kar sakta hoon?";
      default: // english
        return "I understand you're asking about health information. As an AI assistant, I'm here to help with general health questions, but I recommend consulting a healthcare professional for medical advice tailored to your specific situation. How else can I assist you today?";
    }
  }
  
  // Get language specific error responses
  String _getLanguageErrorResponse(String language) {
    switch (language) {
      case 'hindi':
        return "मुझे क्षमा करें, आपके प्रश्न का उत्तर देते समय मुझे एक समस्या का सामना करना पड़ा। कृपया अपना प्रश्न दोबारा पूछें या बाद में फिर से प्रयास करें।";
      case 'hinglish':
        return "Sorry, aapke question ka answer dete waqt mujhe ek problem hui. Kripya apna question dobara poochein ya thodi der baad try karein.";
      default: // english
        return "I apologize, but I encountered an error while processing your question. Could you please try again with a different question?";
    }
  }
} 