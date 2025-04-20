import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/services/ai_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/models/pre_anamnesis_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/models/report_model.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

// Providers for services
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? options;
  final String? voiceNoteUrl;
  final bool reportActions;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.options,
    this.voiceNoteUrl,
    this.reportActions = false,
  });
}

class PreAnamnesisPage extends ConsumerStatefulWidget {
  const PreAnamnesisPage({super.key});

  @override
  ConsumerState<PreAnamnesisPage> createState() => _PreAnamnesisPageState();
}

class _PreAnamnesisPageState extends ConsumerState<PreAnamnesisPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isCompleted = false;
  String _selectedLanguage = 'english'; // Default language
  
  // Patient data collected during the conversation
  final Map<String, dynamic> _patientData = {
    'mainSymptoms': '',
    'duration': '',
    'treatments': '',
    'painLevel': '',
    'medicalHistory': '',
    'additionalInfo': '',
  };
  
  UserModel? _currentUser;
  String _lastGeneratedReport = ''; // Store the last generated report for sharing

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _showLanguageSelectionDialog();
  }

  Future<void> _loadUserData() async {
    final authService = ref.read(authServiceProvider);
    _currentUser = await authService.getCurrentUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showLanguageSelectionDialog() {
    // Delay to ensure context is available
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Select Your Preferred Language'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please select the language you would like to use for chatting with the AI health assistant:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(
                'English',
                'Communicate in standard English',
                'english',
              ),
              const SizedBox(height: 10),
              _buildLanguageOption(
                'Hinglish',
                'Mix of Hindi and English words',
                'hinglish',
              ),
              const SizedBox(height: 10),
              _buildLanguageOption(
                'हिंदी (Hindi)',
                'Communicate in Hindi with Devanagari script',
                'hindi',
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLanguageOption(String title, String subtitle, String languageCode) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedLanguage = languageCode;
        });
        Navigator.of(context).pop();
        _startChat();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.language,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat() {
    // Initial message from AI based on selected language
    String initialMessage;
    List<String> options;
    
    switch (_selectedLanguage) {
      case 'hindi':
        initialMessage = 'नमस्ते! मैं आपका मेडीकनेक्ट सहायक हूँ। आपकी अपॉइंटमेंट से पहले, मैं आपके लक्षणों के बारे में कुछ प्रश्न पूछना चाहूंगा। यह आपके डॉक्टर को आपकी विजिट के लिए तैयार करने में मदद करेगा। क्या आप आगे बढ़ना चाहेंगे?';
        options = ['हां, मैं तैयार हूँ', 'नहीं, शायद बाद में'];
        break;
      case 'hinglish':
        initialMessage = 'Hello! Main aapka MediConnect assistant hoon. Aapki appointment se pehle, main aapke symptoms ke baare mein kuch questions poochna chahoonga. Yeh aapke doctor ko aapki visit ke liye prepare karne mein help karega. Kya aap aage badhna chahenge?';
        options = ['Haan, main ready hoon', 'Nahi, shayad baad mein'];
        break;
      default: // english
        initialMessage = 'Hello! I\'m your MediConnect assistant. Before your appointment, I\'d like to ask you a few questions about your symptoms. This will help your doctor prepare for your visit. Would you like to proceed?';
        options = ['Yes, I\'m ready', 'No, maybe later'];
    }
    
    _addBotMessage(
      initialMessage,
      options: options,
    );
  }

  void _addBotMessage(String text, {List<String>? options, String? voiceNoteUrl}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        options: options,
        voiceNoteUrl: voiceNoteUrl,
      ));
      _isLoading = false;
    });
    
    // Scroll to bottom after message is added
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addUserMessage(String text) {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });
    
    // Scroll to bottom after message is added
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    // Handle user message with AI
    _handleUserMessage(text);
  }

  Future<void> _handleUserMessage(String text) async {
    final aiService = ref.read(aiServiceProvider);
    final currentMessageIndex = _messages.length;
    
    // Store user information in the appropriate category
    if (currentMessageIndex == 2) { // First user response
      if (_selectedLanguage == 'hindi' && text.contains('नहीं')) {
        _addBotMessage(
          'कोई बात नहीं। आप बाद में जब तैयार हों तब असेसमेंट पूरा कर सकते हैं। क्या कोई अन्य जानकारी है जिसमें मैं आपकी सहायता कर सकता हूँ?',
          options: ['होम पेज पर वापस जाएं', 'एक त्वरित प्रश्न पूछें'],
        );
        return;
      } else if (_selectedLanguage == 'hinglish' && text.toLowerCase().contains('nahi')) {
        _addBotMessage(
          'Koi baat nahi. Aap assessment ko baad mein complete kar sakte hain jab aap ready hon. Kya koi aur cheez hai jisme main aapki help kar sakta hoon?',
          options: ['Home page par wapas jaayein', 'Ek quick question poochein'],
        );
        return;
      } else if (_selectedLanguage == 'english' && text.toLowerCase().contains('no')) {
        _addBotMessage(
          'No problem. You can complete the assessment later when you\'re ready. Is there anything else I can help you with?',
          options: ['Return to home', 'Ask a quick question'],
        );
        return;
      }
    } else if (currentMessageIndex == 4) { // After symptom description
      _patientData['mainSymptoms'] = text;
    } else if (currentMessageIndex == 6) { // After timing response
      _patientData['duration'] = text;
    } else if (currentMessageIndex == 8) { // After medications response
      _patientData['treatments'] = text;
    } else if (currentMessageIndex == 10) { // After pain scale
      _patientData['painLevel'] = text;
    } else if (currentMessageIndex == 12) { // After allergies
      _patientData['medicalHistory'] = text;
    } else if (currentMessageIndex == 14) { // After additional info
      _patientData['additionalInfo'] = text;
    }
    
    try {
      String aiResponse = '';
      
      // Using conversation flow logic to determine AI response
      if (currentMessageIndex == 2) { // After first user response
        if (_selectedLanguage == 'hindi') {
          aiResponse = 'शुक्रिया! कृपया अपनी विजिट का मुख्य कारण बताएं? आप किन लक्षणों का अनुभव कर रहे हैं?';
        } else if (_selectedLanguage == 'hinglish') {
          aiResponse = 'Great! Kya aap apne visit ka main reason bata sakte hain? Aap kon se symptoms experience kar rahe hain?';
        } else { // english
          aiResponse = 'Great! Could you please describe the main reason for your visit? What symptoms are you experiencing?';
        }
      } else if (currentMessageIndex == 4) { // After symptoms description
        if (_selectedLanguage == 'hindi') {
          aiResponse = 'जानकारी देने के लिए धन्यवाद। ये लक्षण पहली बार कब शुरू हुए थे?';
        } else if (_selectedLanguage == 'hinglish') {
          aiResponse = 'Thank you for sharing that. Ye symptoms pehli baar kab start hue the?';
        } else { // english
          aiResponse = 'Thank you for sharing that. When did these symptoms first start?';
        }
      } else if (currentMessageIndex == 6) { // After timing response
        if (_selectedLanguage == 'hindi') {
          aiResponse = 'क्या आपने इस स्थिति के लिए कोई दवा या उपचार आजमाया है? यदि हां, तो कृपया बताएं कि आपने क्या आजमाया है और क्या इससे मदद मिली।';
        } else if (_selectedLanguage == 'hinglish') {
          aiResponse = 'Kya aapne is condition ke liye koi medications ya treatments try kiye hain? Agar haan, to please batayein aapne kya try kiya aur kya usse help mili.';
        } else { // english
          aiResponse = 'Have you tried any medications or treatments for this condition? If yes, please describe what you\'ve tried and whether it helped.';
        }
      } else if (currentMessageIndex == 8) { // After medications response
        if (_selectedLanguage == 'hindi') {
          aiResponse = '1 से 10 के पैमाने पर, आप अपने दर्द या तकलीफ को कैसे रेट करेंगे?';
          _addBotMessage(aiResponse, options: ['1-3 (हल्का)', '4-7 (मध्यम)', '8-10 (गंभीर)']);
        } else if (_selectedLanguage == 'hinglish') {
          aiResponse = '1 se 10 ke scale par, aap apne pain ya discomfort ko kaise rate karenge?';
          _addBotMessage(aiResponse, options: ['1-3 (Mild)', '4-7 (Moderate)', '8-10 (Severe)']);
        } else { // english
          aiResponse = 'On a scale from 1 to 10, how would you rate your pain or discomfort?';
          _addBotMessage(aiResponse, options: ['1-3 (Mild)', '4-7 (Moderate)', '8-10 (Severe)']);
        }
        return;
      } else if (currentMessageIndex == 10) { // After pain scale
        if (_selectedLanguage == 'hindi') {
          aiResponse = 'क्या आपको कोई ज्ञात एलर्जी या चल रही चिकित्सीय स्थिति है जिसके बारे में मुझे जानना चाहिए?';
        } else if (_selectedLanguage == 'hinglish') {
          aiResponse = 'Kya aapko koi known allergies ya ongoing medical conditions hain jinke bare mein mujhe pata hona chahiye?';
        } else { // english
          aiResponse = 'Do you have any known allergies or ongoing medical conditions I should be aware of?';
        }
      } else if (currentMessageIndex == 12) { // After allergies
        if (_selectedLanguage == 'hindi') {
          aiResponse = 'सारी जानकारी के लिए धन्यवाद। क्या कोई अन्य जानकारी है जो आप जोड़ना चाहेंगे जो आपके डॉक्टर के लिए प्रासंगिक हो सकती है?';
        } else if (_selectedLanguage == 'hinglish') {
          aiResponse = 'Thank you for all this information. Kya koi aur information hai jo aap add karna chahenge jo aapke doctor ke liye relevant ho sakti hai?';
        } else { // english
          aiResponse = 'Thank you for all this information. Is there anything else you\'d like to add that might be relevant for your doctor?';
        }
      } else if (currentMessageIndex == 14) { // After final info
        if (_selectedLanguage == 'hindi') {
          aiResponse = 'मैंने आपके डॉक्टर के लिए सभी आवश्यक जानकारी एकत्र कर ली है। क्या आप चाहेंगे कि मैं आपके द्वारा साझा की गई जानकारी के आधार पर एक प्री-एनामनेसिस रिपोर्ट तैयार करूं?';
          _addBotMessage(aiResponse, options: ['हां, रिपोर्ट तैयार करें', 'नहीं, मैं समाप्त कर चुका हूँ']);
        } else if (_selectedLanguage == 'hinglish') {
          aiResponse = 'Maine aapke doctor ke liye sabhi necessary information collect kar li hai. Kya aap chahenge ki main aapke dwara share ki gayi information ke basis par ek pre-anamnesis report generate karoon?';
          _addBotMessage(aiResponse, options: ['Haan, report generate karein', 'Nahi, main done hoon']);
        } else { // english
          aiResponse = 'I\'ve collected all the necessary information for your doctor. Would you like me to generate a pre-anamnesis report based on what you\'ve shared?';
          _addBotMessage(aiResponse, options: ['Yes, generate report', 'No, I\'m done']);
        }
        return;
      } else if (currentMessageIndex == 16) { // After report request
        final yesIndicators = {
          'hindi': ['हां', 'तैयार'],
          'hinglish': ['haan', 'generate'],
          'english': ['yes', 'generate'],
        };
        
        final selectedIndicators = yesIndicators[_selectedLanguage] ?? yesIndicators['english']!;
        
        if (selectedIndicators.any((word) => text.toLowerCase().contains(word))) {
          if (!mounted) return;
          
          setState(() {
            _isLoading = true;
          });
          
          try {
            // Generate pre-anamnesis report using AI
            final report = await aiService.generatePreAnamnesis(
              patientDescription: "Patient is seeking medical consultation.",
              symptoms: _patientData['mainSymptoms'] ?? '',
              previousConditions: [_patientData['medicalHistory'] ?? ''],
            );
            
            // Format the report - remove unwanted symbols
            final formattedReport = _formatReport(report);
            _lastGeneratedReport = formattedReport; // Store for sharing
            
            // Save report to Firebase
            if (mounted) {
              try {
                await _savePreAnamnesisToFirebase(formattedReport);
              } catch (e) {
                debugPrint('Error saving pre-anamnesis to Firebase: $e');
                // Continue even if save fails - we'll still show the report
              }
              
              if (_selectedLanguage == 'hindi') {
                aiResponse = 'यहां आपकी प्री-एनामनेसिस रिपोर्ट है:\n\n$formattedReport';
                setState(() {
                  _isCompleted = true;
                  _isLoading = false;
                });
                _addBotMessage(aiResponse);
                _addShareOptions();
              } else if (_selectedLanguage == 'hinglish') {
                aiResponse = 'Yahan aapki pre-anamnesis report hai:\n\n$formattedReport';
                setState(() {
                  _isCompleted = true;
                  _isLoading = false;
                });
                _addBotMessage(aiResponse);
                _addShareOptions();
              } else { // english
                aiResponse = 'Here\'s your pre-anamnesis report:\n\n$formattedReport';
                setState(() {
                  _isCompleted = true;
                  _isLoading = false;
                });
                _addBotMessage(aiResponse);
                _addShareOptions();
              }
            }
          } catch (e) {
            debugPrint('Error generating report: $e');
            
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              // Add a more specific error message instead of just "an error"
              String errorMessage;
              if (e.toString().contains('timeout')) {
                errorMessage = _selectedLanguage == 'hindi' 
                  ? 'रिपोर्ट जनरेट करने का समय समाप्त हो गया। कृपया अपने नेटवर्क कनेक्शन की जांच करें और पुनः प्रयास करें।'
                  : (_selectedLanguage == 'hinglish' 
                      ? 'Report generate karne ka time out ho gaya. Please apne network connection check karein aur dobara try karein.'
                      : 'The report generation timed out. Please check your network connection and try again.');
              } else if (e.toString().contains('network')) {
                errorMessage = _selectedLanguage == 'hindi' 
                  ? 'नेटवर्क त्रुटि के कारण रिपोर्ट जनरेट नहीं की जा सकी। कृपया अपने इंटरनेट कनेक्शन की जांच करें।'
                  : (_selectedLanguage == 'hinglish' 
                      ? 'Network error ke karan report generate nahi ho payi. Please apna internet connection check karein.'
                      : 'The report couldn\'t be generated due to a network error. Please check your internet connection.');
              } else {
                errorMessage = _selectedLanguage == 'hindi' 
                  ? 'रिपोर्ट जनरेट करते समय एक त्रुटि हुई। कृपया बाद में पुनः प्रयास करें।'
                  : (_selectedLanguage == 'hinglish' 
                      ? 'Report generate karte samay ek error hui. Please thodi der baad dobara try karein.'
                      : 'There was an error generating the report. Please try again later.');
              }
              
              if (_selectedLanguage == 'hindi') {
                _addBotMessage('मुझे क्षमा करें, $errorMessage', 
                  options: ['पुन: प्रयास करें', 'सत्र पूरा करें']);
              } else if (_selectedLanguage == 'hinglish') {
                _addBotMessage('Sorry, $errorMessage', 
                  options: ['Dobara try karein', 'Session complete karein']);
              } else { // english
                _addBotMessage('I apologize, $errorMessage', 
                  options: ['Try again', 'Complete session']);
              }
            }
          }
          return;
        } else {
          if (_selectedLanguage == 'hindi') {
            aiResponse = 'क्या कोई अन्य बात है जिसके बारे में आप सत्र समाप्त करने से पहले चर्चा करना चाहेंगे?';
            _addBotMessage(aiResponse, options: ['सत्र पूरा करें', 'एक और प्रश्न पूछें']);
          } else if (_selectedLanguage == 'hinglish') {
            aiResponse = 'Kya koi aur cheez hai jiske bare mein aap session end karne se pehle discuss karna chahenge?';
            _addBotMessage(aiResponse, options: ['Session complete karein', 'Ek aur question poochein']);
          } else { // english
            aiResponse = 'Is there anything else you\'d like to discuss before we end the session?';
            _addBotMessage(aiResponse, options: ['Complete session', 'Ask another question']);
          }
          return;
        }
      } else if (currentMessageIndex == 18) { // Final message
        final completeIndicators = {
          'hindi': ['पूरा', 'समाप्त'],
          'hinglish': ['complete', 'khatam'],
          'english': ['complete', 'end'],
        };
        
        final selectedIndicators = completeIndicators[_selectedLanguage] ?? completeIndicators['english']!;
        
        if (selectedIndicators.any((word) => text.toLowerCase().contains(word))) {
          setState(() {
            _isCompleted = true;
          });
          
          if (_selectedLanguage == 'hindi') {
            aiResponse = 'यह जानकारी प्रदान करने के लिए धन्यवाद। आपके डॉक्टर आपकी अपॉइंटमेंट से पहले इसकी समीक्षा करेंगे। जल्द ही मिलते हैं!';
          } else if (_selectedLanguage == 'hinglish') {
            aiResponse = 'Is information ko provide karne ke liye thank you. Aapke doctor ise aapki appointment se pehle review karenge. Jald hi milenge!';
          } else { // english
            aiResponse = 'Thank you for providing this information. Your doctor will review it before your appointment. See you soon!';
          }
        } else {
          if (_selectedLanguage == 'hindi') {
            aiResponse = 'आप और क्या चर्चा करना या पूछना चाहेंगे?';
          } else if (_selectedLanguage == 'hinglish') {
            aiResponse = 'Aap aur kya discuss karna ya poochna chahenge?';
          } else { // english
            aiResponse = 'What else would you like to discuss or ask about?';
          }
        }
      } else {
        // For any other messages, use the AI to generate a contextual response
        // Create conversation history for context
        List<Map<String, String>> conversationHistory = [];
        for (int i = 0; i < _messages.length; i++) {
          conversationHistory.add({
            'role': _messages[i].isUser ? 'user' : 'assistant',
            'content': _messages[i].text,
          });
        }
        
        // Get AI response with the selected language
        aiResponse = await aiService.generateResponse(
          prompt: text,
          conversationHistory: conversationHistory,
          language: _selectedLanguage,
        );
        
        // Add options for the user if at the end of the pre-anamnesis
        if (_isCompleted) {
          if (_selectedLanguage == 'hindi') {
            _addBotMessage(aiResponse, options: ['सत्र पूरा करें', 'एक और प्रश्न पूछें']);
          } else if (_selectedLanguage == 'hinglish') {
            _addBotMessage(aiResponse, options: ['Session complete karein', 'Ek aur question poochein']);
          } else { // english
            _addBotMessage(aiResponse, options: ['Complete session', 'Ask another question']);
          }
          return;
        }
      }
      
      _addBotMessage(aiResponse);
    } catch (e) {
      debugPrint('Error in _handleUserMessage: $e');
      if (mounted) {
        if (_selectedLanguage == 'hindi') {
          _addBotMessage('मुझे क्षमा करें, लेकिन आपके अनुरोध को संसाधित करते समय मुझे एक त्रुटि का सामना करना पड़ा। कृपया बाद में पुनः प्रयास करें।');
        } else if (_selectedLanguage == 'hinglish') {
          _addBotMessage('I apologize, lekin aapke request ko process karte waqt mujhe ek error mila. Please thodi der baad dobara try karein.');
        } else { // english
          _addBotMessage('I apologize, but I encountered an error processing your request. Please try again later.');
        }
      }
    }
  }

  Future<void> _savePreAnamnesisToFirebase(String reportContent) async {
    if (_currentUser == null) return;
    
    final firebaseService = ref.read(firebaseServiceProvider);
    
    try {
      final preAnamnesis = PreAnamnesisModel(
        id: '', // Will be set by the service
        patientId: _currentUser!.id,
        symptoms: _patientData['mainSymptoms'] ?? '',
        duration: _patientData['duration'] ?? '',
        painLevel: _patientData['painLevel'] ?? '',
        medications: _patientData['treatments'] ?? '',
        allergies: _patientData['medicalHistory'] ?? '',
        additionalInfo: _patientData['additionalInfo'] ?? '',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      
      await firebaseService.createPreAnamnesis(preAnamnesis);
      debugPrint('Pre-anamnesis saved successfully to Firebase');
    } catch (e) {
      debugPrint('Error saving pre-anamnesis to Firebase: $e');
      rethrow; // Use rethrow instead of throw e
    }
  }

  void _handleOptionSelected(String option) {
    _addUserMessage(option);
  }

  void _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      setState(() {
        _isRecording = false;
        _isLoading = true;
      });
      
      // Simulate processing the audio
      // In a real app, this would be actual audio processing
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _isLoading = false;
      });
      
      // Add a simulated transcription
      _addUserMessage("I've been having headaches and feeling dizzy for the past few days, especially in the morning.");
    } else {
      // Start recording
      setState(() {
        _isRecording = true;
      });
      
      try {
        final aiService = ref.read(aiServiceProvider);
        // Call the method but don't store its result if not needed
        await aiService.recordAudio();
        
        // This would be a real implementation in a production app
        // final transcription = await aiService.transcribeAudio(audioFile);
        // _addUserMessage(transcription);
      } catch (e) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record audio: $e')),
        );
      }
    }
  }

  void _finishSession() async {
    // If session is already completed, go to home directly
    if (_isCompleted) {
      Navigator.of(context).pushReplacementNamed(Routes.home);
      return;
    }

    // Show dialog based on selected language
    String title, message, cancelText, confirmText;
    
    if (_selectedLanguage == 'hindi') {
      title = 'सत्र समाप्त करें?';
      message = 'क्या आप वाकई इस सत्र को समाप्त करना चाहते हैं? प्रक्रिया पूरी नहीं होने पर, आपकी प्रगति खो सकती है।';
      cancelText = 'नहीं';
      confirmText = 'समाप्त करें';
    } else if (_selectedLanguage == 'hinglish') {
      title = 'Session end karein?';
      message = 'Kya aap sach mein is session ko end karna chahte hain? Process complete nahi hone par, aapki progress kho sakti hai.';
      cancelText = 'Nahi';
      confirmText = 'End karein';
    } else { // english
      title = 'End session?';
      message = 'Are you sure you want to end this session? If the process is not complete, your progress may be lost.';
      cancelText = 'No';
      confirmText = 'End session';
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Text(message),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceMedium,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelText),
                ),
              ),
              const SizedBox(height: 16), // Add vertical spacing
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      Navigator.of(context).pushReplacementNamed(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedLanguage == 'hindi' 
                    ? 'प्री-विजिट असेसमेंट' 
                    : (_selectedLanguage == 'hinglish' 
                        ? 'Pre-Visit Assessment' 
                        : 'Pre-Visit Assessment')
              ),
              Text(
                _selectedLanguage == 'hindi' 
                    ? 'AI स्वास्थ्य सहायक' 
                    : (_selectedLanguage == 'hinglish' 
                        ? 'AI Health Assistant' 
                        : 'AI Health Assistant'),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                // Show information about the chatbot
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      _selectedLanguage == 'hindi' 
                          ? 'प्री-विजिट असेसमेंट के बारे में' 
                          : (_selectedLanguage == 'hinglish' 
                              ? 'Pre-Visit Assessment ke bare mein' 
                              : 'About Pre-Visit Assessment')
                    ),
                    content: Text(
                      _selectedLanguage == 'hindi' 
                          ? 'यह चैटबॉट आपकी अपॉइंटमेंट से पहले आपके लक्षणों के बारे में जानकारी एकत्र करता है। डेटा सुरक्षित रूप से संग्रहीत किया जाता है और केवल आपके स्वास्थ्य सेवा प्रदाता के साथ साझा किया जाता है। यह एक नैदानिक उपकरण नहीं है और चिकित्सा सलाह की जगह नहीं लेता है।'
                          : (_selectedLanguage == 'hinglish' 
                              ? 'Yeh chatbot aapki appointment se pehle aapke symptoms ke bare mein information collect karta hai. Data securely store kiya jata hai aur sirf aapke healthcare provider ke saath share kiya jata hai. Yeh ek diagnostic tool nahi hai aur medical advice ki jagah nahi leta hai.'
                              : 'This chatbot collects information about your symptoms before your appointment. The data is securely stored and shared only with your healthcare provider. This is not a diagnostic tool and does not replace medical advice.')
                    ),
                    actions: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            _selectedLanguage == 'hindi' 
                                ? 'बंद करें' 
                                : (_selectedLanguage == 'hinglish' 
                                    ? 'Band karein' 
                                    : 'Close')
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    // Show loading indicator
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.medical_services_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Thinking...',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  final message = _messages[index];
                  final isUserMessage = message.isUser;
                  
                  return Align(
                    alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUserMessage ? AppColors.primary : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight: isUserMessage ? const Radius.circular(0) : null,
                          bottomLeft: !isUserMessage ? const Radius.circular(0) : null,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Voice note player if available
                          if (message.voiceNoteUrl != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMedium,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: 50,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '0:30',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          
                          // Message text
                          Text(
                            message.text,
                            style: AppTypography.bodyMedium.copyWith(
                              color: isUserMessage ? AppColors.textLight : AppColors.textPrimary,
                            ),
                          ),
                          
                          // Report action buttons if available
                          if (message.reportActions == true) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _shareReport,
                                    icon: const Icon(Icons.share, color: Colors.white),
                                    label: Text(
                                      _selectedLanguage == 'hindi' 
                                          ? 'रिपोर्ट साझा करें' 
                                          : (_selectedLanguage == 'hinglish' 
                                              ? 'Report share karein' 
                                              : 'Share Report'),
                                      style: AppTypography.bodySmall.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _sendReportToDoctor,
                                    icon: const Icon(Icons.send, color: Colors.white),
                                    label: Text(
                                      _selectedLanguage == 'hindi' 
                                          ? 'डॉक्टर को भेजें' 
                                          : (_selectedLanguage == 'hinglish' 
                                              ? 'Doctor ko bhejein' 
                                              : 'Send to Doctor'),
                                      style: AppTypography.bodySmall.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          // Options buttons if available
                          if (message.options != null && message.options!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: message.options!.map((option) {
                                return InkWell(
                                  onTap: () => _handleOptionSelected(option),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isUserMessage 
                                          ? AppColors.surfaceLight 
                                          : AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Text(
                                      option,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          
                          // Timestamp
                          const SizedBox(height: 4),
                          Text(
                            '${message.timestamp.hour.toString().padLeft(2, '0')}:'
                            '${message.timestamp.minute.toString().padLeft(2, '0')}',
                            style: AppTypography.overline.copyWith(
                              color: isUserMessage 
                                  ? AppColors.textLight.withOpacity(0.7) 
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Input area
            if (!_isCompleted)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Voice recording button
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isRecording 
                              ? AppColors.error.withOpacity(0.1)
                              : AppColors.surfaceMedium,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: _isRecording ? AppColors.error : AppColors.primary,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Text input field
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _isRecording 
                              ? (_selectedLanguage == 'hindi' 
                                  ? 'ऑडियो रिकॉर्ड कर रहे हैं...' 
                                  : (_selectedLanguage == 'hinglish' 
                                      ? 'Audio recording ho raha hai...' 
                                      : 'Recording audio...'))
                              : (_selectedLanguage == 'hindi' 
                                  ? 'अपना संदेश लिखें...' 
                                  : (_selectedLanguage == 'hinglish' 
                                      ? 'Apna message likhein...' 
                                      : 'Type your message...')),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceMedium,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          enabled: !_isRecording && !_isLoading,
                        ),
                        onSubmitted: _addUserMessage,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Send button
                    GestureDetector(
                      onTap: () => _addUserMessage(_messageController.text),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: Icon(
                            Icons.send,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                child: GradientButton(
                  text: _selectedLanguage == 'hindi' 
                      ? 'होम पेज पर वापस जाएं' 
                      : (_selectedLanguage == 'hinglish' 
                          ? 'Home page par wapas jaayein' 
                          : 'Return to Home'),
                  onPressed: _finishSession,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Show confirmation dialog when back button is pressed
  Future<bool> _onWillPop() async {
    if (_isCompleted) {
      return true; // If completed, allow to leave without confirmation
    }
    
    // Show dialog based on selected language
    String title, message, cancelText, confirmText;
    
    if (_selectedLanguage == 'hindi') {
      title = 'बातचीत छोड़ें?';
      message = 'क्या आप वाकई बातचीत से बाहर निकलना चाहते हैं? आपकी सारी प्रगति खो जाएगी।';
      cancelText = 'नहीं';
      confirmText = 'बाहर निकलें';
    } else if (_selectedLanguage == 'hinglish') {
      title = 'Chat leave karein?';
      message = 'Kya aap sach mein chat se bahar nikalna chahte hain? Aapki saari progress kho jayegi.';
      cancelText = 'Nahi';
      confirmText = 'Bahar niklein';
    } else { // english
      title = 'Leave conversation?';
      message = 'Are you sure you want to exit the conversation? All your progress will be lost.';
      cancelText = 'No';
      confirmText = 'Exit';
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Text(message),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        actions: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceMedium,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelText),
                ),
              ),
              const SizedBox(height: 16), // Add vertical spacing
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(confirmText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    
    // Return true to allow exit, false to cancel
    return result ?? false;
  }

  // Format the report to remove unwanted symbols
  String _formatReport(String report) {
    // Remove markdown symbols like #, *, _, -, =
    String formatted = report;
    
    // Replace section headers (lines with # or ##)
    formatted = formatted.replaceAllMapped(RegExp(r'#+\s*(.+)'), (match) {
      return '\n${match.group(1)}\n';
    });
    
    // Remove asterisks used for bold/italics
    formatted = formatted.replaceAll('**', '').replaceAll('*', '');
    
    // Remove underscores used for italics
    formatted = formatted.replaceAll('__', '').replaceAll('_', '');
    
    // Replace bullet points
    formatted = formatted.replaceAllMapped(RegExp(r'\n\s*[-*]\s+(.+)'), (match) {
      return '\n• ${match.group(1)}';
    });
    
    // Replace horizontal rules
    formatted = formatted.replaceAll(RegExp(r'\n-{3,}\n'), '\n\n');
    formatted = formatted.replaceAll(RegExp(r'\n={3,}\n'), '\n\n');
    
    // Replace multiple newlines with double newlines
    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return formatted;
  }
  
  // Add a message with share options
  void _addShareOptions() {
    setState(() {
      _messages.add(ChatMessage(
        text: _selectedLanguage == 'hindi' 
          ? 'आप रिपोर्ट को साझा कर सकते हैं या डॉक्टर को भेज सकते हैं:'
          : (_selectedLanguage == 'hinglish' 
              ? 'Aap report ko share kar sakte hain ya doctor ko bhej sakte hain:'
              : 'You can share the report or send it to your doctor:'),
        isUser: false,
        timestamp: DateTime.now(),
        reportActions: true,
      ));
    });
    
    // Scroll to bottom after message is added
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  // Function to share report to external apps
  Future<void> _shareReport() async {
    try {
      // Create a PDF file with the report
      final pdfFile = await _generatePDF(_lastGeneratedReport);
      
      // Share the PDF file
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'My Pre-Anamnesis Report',
        text: 'Here is my pre-anamnesis report from MediConnect',
      );
    } catch (e) {
      debugPrint('Error sharing report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share report: $e')),
      );
    }
  }
  
  // Generate a PDF document from the report text
  Future<File> _generatePDF(String reportText) async {
    final pdf = pw.Document();
    
    // Parse the report to identify and format sections
    final formattedSections = _parseReportSections(reportText);
    
    // Add a page to the PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Center(
                child: pw.Text(
                  'Pre-Anamnesis Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Date and Time
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Date: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Report content with formatted sections
              ...formattedSections.map((section) {
                if (section.isHeader) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 15),
                      pw.Text(
                        section.text,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Divider(thickness: 1),
                      pw.SizedBox(height: 5),
                    ],
                  );
                } else {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Text(
                      section.text,
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  );
                }
              }).toList(),
              
              // Footer
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Generated by MediConnect',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    // Save the PDF to a file
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/pre_anamnesis_report.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  // Parse the report text to identify sections (headers and content)
  List<ReportSection> _parseReportSections(String reportText) {
    final sections = <ReportSection>[];
    final lines = reportText.split('\n');
    
    bool inSection = false;
    String currentHeader = '';
    String currentContent = '';
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) {
        if (inSection && currentContent.isNotEmpty) {
          sections.add(ReportSection(text: currentContent, isHeader: false));
          currentContent = '';
        }
        continue;
      }
      
      // Check if this is likely a header
      bool isHeader = false;
      
      // Headers are usually short and often contain these key terms
      final headerKeywords = [
        'Patient Information', 'Medical History', 'Symptoms', 
        'Diagnosis', 'Treatment', 'Allergies', 'Medications',
        'Chief Complaint', 'Examination', 'Assessment', 'Plan'
      ];
      
      // Check if line contains header keywords or is all uppercase or ends with colon
      isHeader = headerKeywords.any((keyword) => line.contains(keyword)) || 
                line == line.toUpperCase() || 
                line.endsWith(':') ||
                (line.length < 50 && !line.contains(' and ') && !line.contains(', '));
      
      if (isHeader) {
        // If we were in a section, add the content we've built up
        if (inSection && currentContent.isNotEmpty) {
          sections.add(ReportSection(text: currentContent, isHeader: false));
          currentContent = '';
        }
        
        // Add the header
        sections.add(ReportSection(text: line, isHeader: true));
        inSection = true;
      } else if (inSection) {
        // Add to current content
        if (currentContent.isNotEmpty) {
          currentContent += '\n';
        }
        currentContent += line;
      } else {
        // Content before any header
        sections.add(ReportSection(text: line, isHeader: false));
      }
    }
    
    // Add any remaining content
    if (currentContent.isNotEmpty) {
      sections.add(ReportSection(text: currentContent, isHeader: false));
    }
    
    return sections;
  }

  // Function to send report to doctor
  Future<void> _sendReportToDoctor() async {
    // Check if user is logged in
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to send the report to a doctor')),
      );
      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      
      // Instead of getting only doctors from appointments, get all doctors in the system
      debugPrint("Pre-anamnesis: Fetching all doctors from the system");
      
      // Get all doctors from Firebase
      final allDoctors = await firebaseService.getDoctors();
      
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
      
      debugPrint("Pre-anamnesis: Found ${allDoctors.length} doctors in the system");
      
      if (allDoctors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No doctors found in the system. Please try again later.')),
        );
        return;
      }
      
      // Format doctor data for display
      final doctors = allDoctors.map((doctorData) {
        return {
          'id': doctorData.id,
          'name': doctorData.name,
          'specialty': doctorData.doctorInfo?['specialty'] ?? 'General Practitioner',
          'photoUrl': doctorData.profileImageUrl,
          'experience': doctorData.doctorInfo?['experience'] ?? '0',
        };
      }).toList();
      
      // Sort doctors by name for easier browsing
      doctors.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      
      // Show enhanced dialog to select a doctor
      final selectedDoctor = await _showDoctorSelectionDialog(doctors);
      
      if (selectedDoctor == null) {
        return; // User cancelled
      }
      
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      debugPrint("Pre-anamnesis: Sending report to doctor: ${selectedDoctor['name']} (${selectedDoctor['id']})");
      
      try {
        // Generate PDF report
        await _generatePDF(_lastGeneratedReport); // Don't store the result if not needed
        
        // Create a report model
        final report = ReportModel(
          id: '', // Will be set by the service
          patientId: _currentUser!.id,
          patientName: _currentUser!.name,
          doctorId: selectedDoctor['id'],
          appointmentId: null, // Could be set if we want to link to a specific appointment
          content: _lastGeneratedReport,
          correctedContent: null,
          status: ReportStatus.draft, // Explicitly set status to draft
          isSavedToProfile: false,
          isSentToPatient: false,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          pdfUrl: null, // Will be set if we upload the PDF
        );
        
        // Add debug logging to verify report creation
        debugPrint("Pre-anamnesis: Creating report with status: ${report.status}");
        debugPrint("Pre-anamnesis: Status string value: ${ReportModel.statusToString(report.status)}");
        debugPrint("Pre-anamnesis: Report content length: ${report.content.length} characters");
        debugPrint("Pre-anamnesis: Report doctor ID: ${report.doctorId}");
        
        // Extra verification to ensure status is set
        final reportMap = report.toMap();
        debugPrint("Pre-anamnesis: Status in map: ${reportMap['status']}");
        
        // Send report to Firestore
        final reportId = await firebaseService.createMedicalReport(report);
        debugPrint("Pre-anamnesis: Report created with ID: $reportId");
        
        // Verify the report was saved correctly
        final savedReport = await firebaseService.getReportById(reportId);
        if (savedReport != null) {
          debugPrint("Pre-anamnesis: Verified report saved with status: ${savedReport.status}");
          debugPrint("Pre-anamnesis: Verified report status string: ${ReportModel.statusToString(savedReport.status)}");
          debugPrint("Pre-anamnesis: Verified report saved with doctor ID: ${savedReport.doctorId}");
        } else {
          debugPrint("Pre-anamnesis: Warning - Could not verify report was saved");
        }
        
        // Hide loading indicator
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report sent to Dr. ${selectedDoctor['name']} successfully')),
        );
      } catch (innerError) {
        debugPrint("Pre-anamnesis: Error sending report to doctor: $innerError");
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending report: $innerError')),
        );
      }
    } catch (e) {
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
      
      debugPrint('Error in _sendReportToDoctor: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send report: $e')),
      );
    }
  }
  
  // Enhanced doctor selection dialog with search and filtering
  Future<Map<String, dynamic>?> _showDoctorSelectionDialog(List<Map<String, dynamic>> doctors) async {
    // Controller for search field
    final TextEditingController searchController = TextEditingController();
    
    // State for filtered doctors list
    List<Map<String, dynamic>> filteredDoctors = [...doctors];
    String selectedSpecialty = 'All Specialties';
    
    // Get unique specialties for filtering
    final Set<String> specialties = {'All Specialties'};
    for (var doctor in doctors) {
      if (doctor['specialty'] != null && doctor['specialty'].toString().isNotEmpty) {
        specialties.add(doctor['specialty'].toString());
      }
    }
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Filter function
            void filterDoctors() {
              final searchTerm = searchController.text.toLowerCase();
              setState(() {
                filteredDoctors = doctors.where((doctor) {
                  final matchesSearch = doctor['name'].toString().toLowerCase().contains(searchTerm) ||
                      doctor['specialty'].toString().toLowerCase().contains(searchTerm);
                  
                  final matchesSpecialty = selectedSpecialty == 'All Specialties' || 
                      doctor['specialty'] == selectedSpecialty;
                  
                  return matchesSearch && matchesSpecialty;
                }).toList();
              });
            }
            
            return AlertDialog(
              title: Text(
                _selectedLanguage == 'hindi' 
                    ? 'डॉक्टर को रिपोर्ट भेजें' 
                    : (_selectedLanguage == 'hinglish' 
                        ? 'Doctor ko Report Bhejein' 
                        : 'Send Report to Doctor')
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search field
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: _selectedLanguage == 'hindi' 
                            ? 'डॉक्टर खोजें' 
                            : (_selectedLanguage == 'hinglish' 
                                ? 'Doctor khojein' 
                                : 'Search doctors'),
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        filterDoctors();
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Specialty filter dropdown
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedSpecialty,
                          hint: Text(
                            _selectedLanguage == 'hindi' 
                                ? 'विशेषज्ञता द्वारा फ़िल्टर करें' 
                                : (_selectedLanguage == 'hinglish' 
                                    ? 'Specialty dwara filter karein' 
                                    : 'Filter by specialty')
                          ),
                          items: specialties.map((String specialty) {
                            return DropdownMenuItem<String>(
                              value: specialty,
                              child: Text(specialty),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSpecialty = value!;
                              filterDoctors();
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Doctors list
                    Expanded(
                      child: filteredDoctors.isEmpty
                          ? Center(
                              child: Text(
                                _selectedLanguage == 'hindi' 
                                    ? 'कोई डॉक्टर नहीं मिला' 
                                    : (_selectedLanguage == 'hinglish' 
                                        ? 'Koi doctor nahi mila' 
                                        : 'No doctors found')
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredDoctors.length,
                              itemBuilder: (context, index) {
                                final doctor = filteredDoctors[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, 
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundImage: doctor['photoUrl'] != null 
                                          ? NetworkImage(doctor['photoUrl']) 
                                          : null,
                                      backgroundColor: doctor['photoUrl'] == null 
                                          ? Colors.blue.shade100
                                          : null,
                                      child: doctor['photoUrl'] == null 
                                          ? Text(
                                              doctor['name'].toString().split(' ')
                                                  .map((e) => e.isNotEmpty ? e[0] : '')
                                                  .join()
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.blue.shade800,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    title: Text(
                                      doctor['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(doctor['specialty']),
                                        if (doctor['experience'] != null && doctor['experience'] != '0')
                                          Text('${doctor['experience']} years experience'),
                                      ],
                                    ),
                                    onTap: () => Navigator.of(context).pop(doctor),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    _selectedLanguage == 'hindi' 
                        ? 'रद्द करें' 
                        : (_selectedLanguage == 'hinglish' 
                            ? 'Radd karein' 
                            : 'Cancel')
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Helper class for report sections
class ReportSection {
  final String text;
  final bool isHeader;
  
  ReportSection({required this.text, required this.isHeader});
} 