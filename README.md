# MediConnect

MediConnect is a Flutter application designed to facilitate intelligent interactions between physicians and patients through data collection, therapy management, and AI-powered communication support.

## 📱 App Overview

MediConnect addresses critical challenges in medical care by providing:

- **AI-powered pre-anamnesis** for collecting patient data before appointments
- **Secure communication channels** between doctors and patients
- **Intelligent therapy management** with personalized recommendations
- **Voice transcription** for simplified data input
- **Longitudinal health timeline** for comprehensive patient history

## 🛠️ Technical Stack

- **Frontend**: Flutter with Material Design 3
- **State Management**: Flutter Riverpod
- **Authentication**: Firebase Auth with Google Sign-in
- **Database**: Cloud Firestore
- **AI Integration**: HuggingFace models (Mistral-7B for chat, Whisper for speech-to-text)
- **Storage**: Firebase Storage for secure file handling

## ✨ Core Features

### Patient-Focused Features

- **Smart Onboarding**: Streamlined process with social authentication
- **Pre-Anamnesis Chatbot**: AI-powered symptom collection before appointments
- **Voice Input**: Natural communication with speech-to-text capabilities
- **Appointment Management**: Scheduling, reminders, and history tracking
- **Secure Messaging**: End-to-end encrypted communication with healthcare providers

### Doctor-Focused Features

- **Patient Dashboard**: Comprehensive view of upcoming appointments and requests
- **Pre-filled Patient Information**: Review pre-anamnesis data before appointments
- **Analytics**: Patient trends and practice insights
- **Treatment Tracking**: Monitor patient adherence and progress
- **AI-assisted Diagnosis Support**: Get intelligent recommendations based on patient data

## 🔒 Security & Compliance

- **GDPR Compliance**: Comprehensive data protection measures
- **Data Encryption**: Secure storage of all sensitive information
- **User Consent Management**: Transparent data handling with explicit consent
- **Audit Logging**: Track all data access and modifications

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase account
- HuggingFace API key for AI capabilities

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/medi_connect.git
   cd medi_connect
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Create a `.env` file in the root directory with the following contents:
   ```
   # API Keys
   HUGGINGFACE_API_KEY=your_huggingface_api_key

   # Firebase Configuration
   FIREBASE_PROJECT_ID=your_firebase_project_id
   FIREBASE_APP_ID=your_firebase_app_id
   ```

4. Run the app:
   ```bash
   flutter run
   ```

### Running Tests

1. Create a `.env.test` file for testing with test API keys:
   ```
   # Test API Keys
   HUGGINGFACE_API_KEY=your_test_huggingface_api_key

   # Test Firebase Configuration
   FIREBASE_PROJECT_ID=your_test_firebase_project_id
   FIREBASE_APP_ID=your_test_firebase_app_id
   ```

2. Run the tests:
   ```bash
   flutter test
   ```

### Using the App

1. **First Launch**: On first launch, you'll see an onboarding tutorial explaining the app's features.

2. **Authentication**: 
   - Sign up with your email or use Google Sign-in.
   - For doctor accounts, please contact the administrator.

3. **Patient Flow**:
   - Complete your profile information.
   - Book appointments with available doctors.
   - Use the AI pre-anamnesis before appointments.
   - Chat securely with your healthcare providers.

4. **Doctor Flow**:
   - View your dashboard with upcoming appointments.
   - Review patient pre-anamnesis data.
   - Manage patient communications and follow-ups.
   - Access analytics on patient trends.

## 📊 Project Structure

```
lib/
├── application/       # Use cases, business logic
├── core/              # Shared core functionality
│   ├── config/        # App configuration
│   ├── constants/     # App-wide constants
│   ├── models/        # Data models
│   └── services/      # Core services (Firebase, Auth, AI)
├── data/              # Data sources, repositories
├── domain/            # Domain entities and interfaces
├── infrastructure/    # Implementation of repositories
└── presentation/      # UI components
    ├── pages/         # App screens
    │   ├── auth/      # Authentication screens
    │   ├── chat/      # Messaging screens
    │   ├── doctor/    # Doctor-specific screens
    │   ├── home/      # Home screen and tabs
    │   └── patient/   # Patient-specific screens
    └── widgets/       # Reusable UI components
```

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgements

- [Flutter](https://flutter.dev/) for the amazing cross-platform framework
- [Firebase](https://firebase.google.com/) for backend services
- [HuggingFace](https://huggingface.co/) for ML models and services
