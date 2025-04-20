import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

class AIModel {
  final String id;
  final String name;
  final String description;
  
  AIModel({
    required this.id,
    required this.name,
    required this.description,
  });
}

class AIService {
  final Dio _dio = Dio();
  
  // Open Router API endpoint
  final String _openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  
  // Open Router API Key
  final String _openRouterApiKey = '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';
  
  // Default model
  String _currentModelId = 'meta-llama/llama-3-70b-instruct';
  
  // Available models
  final List<AIModel> availableModels = [
    AIModel(
      id: 'anthropic/claude-3-sonnet:beta',
      name: 'Claude 3 Sonnet',
      description: 'Balanced performance and speed',
    ),
    AIModel(
      id: 'meta-llama/llama-3-70b-instruct',
      name: 'Llama 3 70B',
      description: 'Open source model with high capabilities',
    ),
    AIModel(
      id: 'mistralai/mistral-large',
      name: 'Mistral Large',
      description: 'Balanced open source model',
    ),
    AIModel(
      id: 'cohere/command-r-plus',
      name: 'Command R+',
      description: 'Specialized for factual responses',
    ),
  ];
  
  // Get and set the current model
  String get currentModelId => _currentModelId;
  
  // Add setter for current model id
  set currentModelId(String modelId) {
    setModel(modelId);
  }
  
  void setModel(String modelId) {
    if (availableModels.any((model) => model.id == modelId)) {
      _currentModelId = modelId;
      debugPrint('AIService: Model set to $_currentModelId');
    } else {
      debugPrint('AIService: Invalid model ID, keeping current model $_currentModelId');
    }
  }
  
  // Test the API connection
  Future<bool> testConnection() async {
    try {
      final apiKey = _openRouterApiKey;
      if (apiKey.isEmpty) {
        debugPrint('AIService: API key is empty');
        return false;
      }
      
      debugPrint('AIService: Testing connection with API key: ${apiKey.substring(0, 4)}...');
      
      final response = await _dio.get(
        '$_openRouterBaseUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'HTTP-Referer': 'https://medi-connect.app',
            'X-Title': 'MediConnect Health App',
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
  
  // Generate pre-anamnesis with Open Router
  Future<String> generatePreAnamnesis({
    required String patientDescription,
    required String symptoms,
    required List<String> previousConditions,
  }) async {
    try {
      debugPrint('AIService: Generating pre-anamnesis report using model: $_currentModelId');
      
      // If symptoms or patient description is too short, add default info
      final finalSymptoms = symptoms.length < 5 ? 
          "General discomfort, fatigue, and mild pain. $symptoms" : symptoms;
      
      final finalPatientDesc = patientDescription.length < 10 ? 
          "Patient seeking medical consultation for recent health concerns. $patientDescription" : patientDescription;
      
      final messages = [
        {
          "role": "system",
          "content": "You are a medical assistant helping to generate a pre-anamnesis report. Your task is to analyze the patient's description, symptoms, and medical history to create a structured report that will be useful for a physician. Include potential diagnoses, recommended tests, and follow-up questions. Format the output in markdown with clear sections."
        },
        {
          "role": "user",
          "content": "Please generate a pre-anamnesis report based on the following information:\n\nPatient Description: $finalPatientDesc\nSymptoms: $finalSymptoms\nPrevious Medical Conditions: ${previousConditions.join(', ')}"
        }
      ];
      
      try {
        final response = await _dio.post(
          '$_openRouterBaseUrl/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $_openRouterApiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://medi-connect.app',
              'X-Title': 'MediConnect Health App',
            },
            receiveTimeout: const Duration(seconds: 60),
            sendTimeout: const Duration(seconds: 30),
          ),
          data: jsonEncode({
            'model': _currentModelId,
            'messages': messages,
            'max_tokens': 800,
            'temperature': 0.7,
            'top_p': 0.95,
          }),
        );
        
        if (response.statusCode == 200) {
          debugPrint('AIService: Pre-anamnesis report generated successfully');
          final result = response.data;
          final generatedText = result['choices'][0]['message']['content'] ?? '';
          
          if (generatedText.isNotEmpty) {
            return generatedText;
          } else {
            debugPrint('AIService: Empty response from API, using fallback');
            return _generateFallbackPreAnamnesis(finalPatientDesc, finalSymptoms, previousConditions);
          }
        } else {
          debugPrint('AIService: Failed to generate pre-anamnesis: Status ${response.statusCode}');
          return _generateFallbackPreAnamnesis(finalPatientDesc, finalSymptoms, previousConditions);
        }
      } catch (apiError) {
        debugPrint('AIService: API error while generating pre-anamnesis: $apiError');
        return _generateFallbackPreAnamnesis(finalPatientDesc, finalSymptoms, previousConditions);
      }
    } catch (e) {
      debugPrint('AIService: Exception generating pre-anamnesis: $e');
      return _generateFallbackPreAnamnesis(patientDescription, symptoms, previousConditions);
    }
  }
  
  // Generate a fallback pre-anamnesis report when the API fails
  String _generateFallbackPreAnamnesis(String patientDescription, String symptoms, List<String> previousConditions) {
    final dateTime = DateTime.now();
    final date = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}";
    
    return """
# Pre-Anamnesis Report
**Date**: $date

## Patient Information
The patient is seeking medical consultation for health concerns.

## Chief Complaint
$symptoms

## Medical History
${previousConditions.join(', ')}

## Assessment and Recommendations
Based on the information provided, the patient is experiencing symptoms that warrant medical attention. A full evaluation by a healthcare provider is recommended to determine the proper diagnosis and treatment plan.

### Potential Concerns
- Evaluation of symptom severity and duration
- Assessment of any underlying conditions
- Consideration of appropriate diagnostic tests

### Recommendations
1. Schedule an appointment with a healthcare provider
2. Monitor symptoms and note any changes
3. Prepare a list of questions for the healthcare provider
4. Bring a list of current medications to the appointment

This pre-anamnesis report is based on limited information and is not a substitute for professional medical advice, diagnosis, or treatment.
""";
  }
  
  // Chat with AI for doctor-patient communication
  Future<String> generateResponse({
    required String prompt,
    required List<Map<String, String>> conversationHistory,
    String language = 'english', // Add language parameter with default value
  }) async {
    try {
      debugPrint('AIService: Generating response using model: $_currentModelId for: "${prompt.substring(0, min(20, prompt.length))}..." in $language');
      
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
      
      // Format the conversation history into proper chat messages
      final List<Map<String, dynamic>> messages = [];
      
      // Add system message with instructions - make it focused and specific to MediConnect
      messages.add({
        "role": "system",
        "content": "You are MediConnect AI, an advanced health assistant designed to provide helpful, accurate, and compassionate health information. You are friendly, empathetic, and conversational - respond like a thoughtful health professional having a real conversation. You are knowledgeable about medical topics, but always clarify you're not a licensed healthcare provider.\n\n$languageInstructions\n\nYour capabilities:\n1. Answer health questions with evidence-based information\n2. Explain medical terminology in simple terms\n3. Advise users when to seek professional medical help\n4. Provide general wellness, nutrition, and preventive health guidance\n5. Respond with empathy to health concerns\n\nAlways respond directly to what the user is asking in this specific message. Be concise but thorough in your answers."
      });
      
      // Process and add conversation history
      if (conversationHistory.isNotEmpty) {
        // Use only the last 10 messages to keep context manageable
        final recentHistory = conversationHistory.length <= 10 
            ? conversationHistory 
            : conversationHistory.sublist(conversationHistory.length - 10);
            
        for (var message in recentHistory) {
          if (message['role'] != null && message['content'] != null) {
            messages.add({
              "role": message['role']!,
              "content": message['content']!,
            });
          }
        }
      }
      
      // Add current prompt if not already in history
      bool promptAlreadyInHistory = false;
      if (conversationHistory.isNotEmpty) {
        final lastMessage = conversationHistory.last;
        if (lastMessage['role'] == 'user' && lastMessage['content'] == prompt) {
          promptAlreadyInHistory = true;
        }
      }
      
      if (!promptAlreadyInHistory) {
        messages.add({
          "role": "user",
          "content": prompt,
        });
      }
      
      debugPrint('AIService: Sending ${messages.length} messages to API');
      
      // Timeout for API request to prevent hanging UI
      final response = await _dio.post(
        '$_openRouterBaseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openRouterApiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://medi-connect.app',
            'X-Title': 'MediConnect Health App',
          },
          receiveTimeout: const Duration(seconds: 30), 
          sendTimeout: const Duration(seconds: 30),
        ),
        data: jsonEncode({
          'model': _currentModelId,
          'messages': messages,
          'max_tokens': 1000,
          'temperature': 0.7,
          'top_p': 0.95,
        }),
      );
      
      // Process response more reliably
      if (response.statusCode == 200) {
        final result = response.data;
        debugPrint('AIService: Got response from API');
        
        try {
          if (result != null && 
              result['choices'] != null && 
              result['choices'].isNotEmpty && 
              result['choices'][0]['message'] != null) {
            
            final generatedText = result['choices'][0]['message']['content'] ?? '';
            
            debugPrint('AIService: Response generated successfully. Length: ${generatedText.length}');
            
            if (generatedText.isNotEmpty) {
              return generatedText;
            }
          }
        } catch (parseError) {
          debugPrint('AIService: Error parsing response: $parseError');
        }
        
        // If we reached here, there was a problem with the response structure or content
        return _getLanguageFallbackResponse(language);
      } else {
        debugPrint('AIService: Failed to generate response: Status ${response.statusCode}');
        return _getLanguageErrorResponse(language);
      }
    } catch (e) {
      // Enhanced error handling with specific error types
      String errorMessage;
      
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout || 
            e.type == DioExceptionType.sendTimeout) {
          debugPrint('AIService: Timeout error: ${e.message}');
          errorMessage = _getLanguageTimeoutResponse(language);
        } else if (e.type == DioExceptionType.connectionError) {
          debugPrint('AIService: Connection error: ${e.message}');
          errorMessage = _getLanguageConnectionErrorResponse(language);
        } else {
          debugPrint('AIService: DioError: ${e.type} - ${e.message}');
          errorMessage = _getLanguageErrorResponse(language);
        }
      } else {
        debugPrint('AIService: General exception: $e');
        errorMessage = _getLanguageErrorResponse(language);
      }
      
      return errorMessage;
    }
  }
  
  // Transcribe audio using Open Router models
  Future<String> transcribeAudio(File audioFile) async {
    try {
      debugPrint('AIService: Attempting to transcribe audio file: ${audioFile.path}');
      
      // For now, we'll use a simulated transcription for testing
      // In a production app, you would use a dedicated transcription API like:
      // - OpenAI Whisper API
      // - Google Speech-to-Text
      // - Azure Speech Service
      
      // Generate a simulated transcription based on the file timestamp
      final fileNameParts = audioFile.path.split('/');
      final fileName = fileNameParts.last;
      
      // Extract timestamp from filename (assuming format: audio_timestamp.m4a)
      String timestamp = '';
      RegExp regex = RegExp(r'audio_(\d+)');
      Match? match = regex.firstMatch(fileName);
      if (match != null && match.groupCount >= 1) {
        timestamp = match.group(1) ?? '';
      }
      
      // Generate a realistic transcription with varying content based on timestamp
      // This is just for development/testing
      final lastDigit = timestamp.isNotEmpty ? int.parse(timestamp[timestamp.length - 1]) : 0;
      
      switch(lastDigit) {
        case 0:
          return "I've been having a headache for the past few days, and over-the-counter medication isn't helping. What should I do?";
        case 1:
          return "My throat has been sore and I have a mild fever. Could this be COVID or just a common cold?";
        case 2:
          return "I'm experiencing pain in my lower back, especially when I stand up after sitting for a long time.";
        case 3:
          return "What are some good exercises I can do to improve my heart health?";
        case 4:
          return "I've been feeling more tired than usual lately, even after getting enough sleep. Could this be a vitamin deficiency?";
        case 5:
          return "Is it normal to have joint pain after starting a new exercise routine?";
        case 6:
          return "What foods should I avoid if I have high blood pressure?";
        case 7:
          return "I've been experiencing frequent heartburn, especially after meals. What could be causing this?";
        case 8:
          return "My child has a rash that appeared suddenly. When should I be concerned enough to see a doctor?";
        case 9:
          return "Can you explain what causes seasonal allergies and what treatments are most effective?";
        default:
          return "I have a medical question about my symptoms. Can you help me understand what might be wrong?";
      }
      
      /* 
      // Real implementation would look like this:
      // Convert audio to base64
      final bytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(bytes);
      
      final response = await _dio.post(
        'https://api.openai.com/v1/audio/transcriptions',  // OpenAI's Whisper API
        options: Options(
          headers: {
            'Authorization': 'Bearer YOUR_OPENAI_API_KEY',
            'Content-Type': 'multipart/form-data',
          },
        ),
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: 'audio.m4a',
            contentType: MediaType('audio', 'm4a'),
          ),
          'model': 'whisper-1',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return data['text'] ?? '';
      } else {
        throw Exception('Failed to transcribe audio: ${response.data}');
      }
      */
    } catch (e) {
      debugPrint('AIService: Exception in transcribeAudio: $e');
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
      final messages = [
        {
          "role": "system",
          "content": "You are a medical assistant helping doctors with treatment recommendations. Based on the pre-anamnesis report, suggest potential treatment approaches, medications, lifestyle changes, and follow-up care. Always emphasize that these are suggestions for the physician to consider, not direct medical advice."
        },
        {
          "role": "user",
          "content": "Please provide treatment recommendations for the physician to consider based on this pre-anamnesis report:\n\n$preAnamnesis"
        }
      ];
      
      final response = await _dio.post(
        '$_openRouterBaseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openRouterApiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://medi-connect.app',
            'X-Title': 'MediConnect Health App',
          },
        ),
        data: jsonEncode({
          'model': _currentModelId,
          'messages': messages,
          'max_tokens': 800,
          'temperature': 0.7,
          'top_p': 0.95,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = response.data;
        final generatedText = result['choices'][0]['message']['content'] ?? '';
        
        return generatedText.isNotEmpty 
            ? generatedText 
            : 'Sorry, I could not generate treatment recommendations.';
      } else {
        return 'Sorry, I could not generate treatment recommendations due to a server error.';
      }
    } catch (e) {
      debugPrint('AIService: Exception generating treatment recommendations: $e');
      return 'Sorry, I could not generate treatment recommendations due to an error.';
    }
  }
  
  // Utility to get the minimum of two numbers
  int min(int a, int b) => a < b ? a : b;
  
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
  
  // Add new timeout specific error responses
  String _getLanguageTimeoutResponse(String language) {
    switch (language) {
      case 'hindi':
        return "मुझे क्षमा करें, आपके प्रश्न का उत्तर खोजने में बहुत समय लग रहा है। कृपया अपने नेटवर्क कनेक्शन की जांच करें और कुछ क्षणों बाद पुनः प्रयास करें।";
      case 'hinglish':
        return "Sorry, aapke question ka answer dhoondhne mein bahut time lag raha hai. Please apne network connection ko check karein aur kuch der baad phir se try karein.";
      default: // english
        return "I apologize, but your request is taking longer than expected to process. Please check your network connection and try again in a moment.";
    }
  }
  
  // Add new connection error specific responses
  String _getLanguageConnectionErrorResponse(String language) {
    switch (language) {
      case 'hindi':
        return "मुझे क्षमा करें, सर्वर से कनेक्ट करने में समस्या हो रही है। कृपया अपने इंटरनेट कनेक्शन की जांच करें और कुछ क्षणों बाद पुनः प्रयास करें।";
      case 'hinglish':
        return "Sorry, server se connect karne mein problem ho rahi hai. Please apne internet connection ko check karein aur kuch der baad phir se try karein.";
      default: // english
        return "I apologize, but I'm having trouble connecting to the server. Please check your internet connection and try again in a moment.";
    }
  }
} 