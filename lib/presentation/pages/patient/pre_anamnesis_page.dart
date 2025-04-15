import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/services/ai_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/models/pre_anamnesis_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

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
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.options,
    this.voiceNoteUrl,
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
            
            // Save report to Firebase
            if (mounted) {
              try {
                await _savePreAnamnesisToFirebase(report);
              } catch (e) {
                debugPrint('Error saving pre-anamnesis to Firebase: $e');
                // Continue even if save fails - we'll still show the report
              }
              
              if (_selectedLanguage == 'hindi') {
                aiResponse = 'यहां आपकी प्री-एनामनेसिस रिपोर्ट है:\n\n$report\n\nयह जानकारी सुरक्षित रखी गई है और आपकी अपॉइंटमेंट से पहले आपके डॉक्टर के लिए उपलब्ध होगी। क्या आप सत्र को अब पूरा करना चाहेंगे?';
                setState(() {
                  _isCompleted = true;
                  _isLoading = false;
                });
                _addBotMessage(aiResponse, options: ['सत्र पूरा करें', 'एक और प्रश्न पूछें']);
              } else if (_selectedLanguage == 'hinglish') {
                aiResponse = 'Yahan aapki pre-anamnesis report hai:\n\n$report\n\nYeh information save kar di gayi hai aur aapke doctor ko aapki appointment se pehle available hogi. Kya aap session ko ab complete karna chahenge?';
                setState(() {
                  _isCompleted = true;
                  _isLoading = false;
                });
                _addBotMessage(aiResponse, options: ['Session complete karein', 'Ek aur question poochein']);
              } else { // english
                aiResponse = 'Here\'s your pre-anamnesis report:\n\n$report\n\nThis information has been saved and will be available to your doctor before your appointment. Would you like to complete the session now?';
                setState(() {
                  _isCompleted = true;
                  _isLoading = false;
                });
                _addBotMessage(aiResponse, options: ['Complete session', 'Ask another question']);
              }
            }
          } catch (e) {
            debugPrint('Error generating report: $e');
            
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              
              if (_selectedLanguage == 'hindi') {
                _addBotMessage('मुझे क्षमा करें, रिपोर्ट तैयार करते समय एक त्रुटि हुई। क्या आप पुन: प्रयास करना चाहेंगे?', 
                  options: ['पुन: प्रयास करें', 'सत्र पूरा करें']);
              } else if (_selectedLanguage == 'hinglish') {
                _addBotMessage('Sorry, report generate karte time ek error hui. Kya aap dobara try karna chahenge?', 
                  options: ['Dobara try karein', 'Session complete karein']);
              } else { // english
                _addBotMessage('I apologize, there was an error generating the report. Would you like to try again?', 
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
      throw e; // Rethrow so the caller knows there was an error
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
        final audioFile = await aiService.recordAudio();
        
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
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceMedium,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
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
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          _selectedLanguage == 'hindi' 
                              ? 'बंद करें' 
                              : (_selectedLanguage == 'hinglish' 
                                  ? 'Band karein' 
                                  : 'Close')
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
        content: Text(message),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceMedium,
              foregroundColor: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    // Return true to allow exit, false to cancel
    return result ?? false;
  }
} 