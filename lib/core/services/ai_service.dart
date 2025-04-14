import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

class AIService {
  final Dio _dio = Dio();
  
  // HuggingFace API endpoints
  final String _huggingFaceBaseUrl = 'https://api-inference.huggingface.co/models';
  final String _chatModelId = 'mistralai/Mistral-7B-Instruct-v0.2';
  final String _whisperModelId = 'openai/whisper-large-v3';
  
  // API Key
  String get _huggingFaceApiKey => dotenv.env['HUGGINGFACE_API_KEY'] ?? '';
  
  // Generate pre-anamnesis with HuggingFace
  Future<String> generatePreAnamnesis({
    required String patientDescription,
    required String symptoms,
    required List<String> previousConditions,
  }) async {
    try {
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
        final result = response.data;
        return result[0]['generated_text'] ?? 'Sorry, I could not generate a pre-anamnesis report.';
      } else {
        throw Exception('Failed to generate pre-anamnesis: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to generate pre-anamnesis: $e');
    }
  }
  
  // Chat with AI for doctor-patient communication
  Future<String> generateResponse({
    required String prompt,
    required List<Map<String, String>> conversationHistory,
  }) async {
    try {
      // Format conversation history
      final formattedHistory = conversationHistory.map((message) {
        final role = message['role'] == 'user' ? 'User' : 'Assistant';
        return '$role: ${message['content']}';
      }).join('\n');
      
      final promptWithHistory = '''
      <s>[INST] You are a medical assistant facilitating communication between doctors and patients.
      Provide clear, concise, and medically accurate information. Do not provide medical
      advice, but help clarify medical terms and concepts. Always recommend consulting
      healthcare professionals for specific medical concerns.
      
      Previous conversation:
      $formattedHistory
      
      User's message: $prompt [/INST]</s>
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
          'inputs': promptWithHistory,
          'parameters': {
            'max_new_tokens': 300,
            'temperature': 0.7,
            'top_p': 0.95,
            'do_sample': true,
          },
        }),
      );
      
      if (response.statusCode == 200) {
        final result = response.data;
        return result[0]['generated_text'] ?? 'Sorry, I could not generate a response.';
      } else {
        throw Exception('Failed to generate response: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to generate response: $e');
    }
  }
  
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
        return result[0]['generated_text'] ?? 'Sorry, I could not generate treatment recommendations.';
      } else {
        throw Exception('Failed to generate treatment recommendations: Status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to generate treatment recommendations: $e');
    }
  }
} 