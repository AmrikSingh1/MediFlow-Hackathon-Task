import 'package:flutter/material.dart';
import 'package:medi_connect/presentation/pages/auth/login_page.dart';
import 'package:medi_connect/presentation/pages/auth/register_page.dart';
import 'package:medi_connect/presentation/pages/auth/onboarding_page.dart';
import 'package:medi_connect/presentation/pages/splash_page.dart';
import 'package:medi_connect/presentation/pages/home/home_page.dart';
import 'package:medi_connect/presentation/pages/patient/patient_profile_page.dart';
import 'package:medi_connect/presentation/pages/patient/pre_anamnesis_page.dart';
import 'package:medi_connect/presentation/pages/patient/book_appointment_page.dart';
import 'package:medi_connect/presentation/pages/doctor/doctor_dashboard_page.dart';
import 'package:medi_connect/presentation/pages/doctor/doctor_profile_page.dart';
import 'package:medi_connect/presentation/pages/doctor/patient_detail_page.dart';
import 'package:medi_connect/presentation/pages/doctor/report_review_page.dart';
import 'package:medi_connect/presentation/pages/doctor/report_details_page.dart';
import 'package:medi_connect/presentation/pages/patient/find_doctor_page.dart';
import 'package:medi_connect/presentation/pages/chat/chat_page.dart';
import 'package:medi_connect/core/widgets/health_icon_showcase.dart';
import 'package:medi_connect/presentation/pages/appointment/appointment_details_page.dart';
import 'package:medi_connect/presentation/pages/documents/medical_documents_page.dart';
import 'package:medi_connect/presentation/pages/doctor/invite_patient_page.dart';
import 'package:medi_connect/presentation/pages/patient/view_invitations_page.dart';

// Route names as constants
class Routes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String patientProfile = '/patient/profile';
  static const String preAnamnesis = '/patient/pre-anamnesis';
  static const String bookAppointment = '/patient/book-appointment';
  static const String doctorDashboard = '/doctor/dashboard';
  static const String doctorProfile = '/doctor/profile';
  static const String patientDetail = '/doctor/patient/:id';
  static const String findDoctor = '/patient/find-doctor';
  static const String chat = '/chat/:id';
  static const String completeProfile = '/complete-profile';
  static const String healthIcons = '/health-icons';
  static const String appointmentDetails = '/appointment/:id';
  static const String medicalDocuments = '/documents';
  static const String reportDetails = '/reports/:id';
  static const String reviewReport = '/reports/:id/review';
  static const String invitePatient = '/doctor/invite-patient';
  static const String viewInvitations = '/patient/invitations';
}

// GoRouter could be used for more complex routing, but for simplicity
// let's use the standard Navigator 2.0 routing with pages
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashPage(),
          settings: settings,
        );
        
      case Routes.onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingPage(),
          settings: settings,
        );
        
      case Routes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
        
      case Routes.register:
        return MaterialPageRoute(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
        
      case Routes.home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
          settings: settings,
        );
        
      case Routes.patientProfile:
        return MaterialPageRoute(
          builder: (_) => const PatientProfilePage(),
          settings: settings,
        );
        
      case Routes.preAnamnesis:
        return MaterialPageRoute(
          builder: (_) => const PreAnamnesisPage(),
          settings: settings,
        );
        
      case Routes.bookAppointment:
        // Extract the doctorId from the route arguments
        final Map<String, dynamic>? args = settings.arguments as Map<String, dynamic>?;
        final String doctorId = args?['doctorId'] ?? '';
        return MaterialPageRoute(
          builder: (_) => BookAppointmentPage(doctorId: doctorId),
          settings: settings,
        );
        
      case Routes.doctorDashboard:
        return MaterialPageRoute(
          builder: (_) => const DoctorDashboardPage(),
          settings: settings,
        );
        
      case Routes.doctorProfile:
        return MaterialPageRoute(
          builder: (_) => const DoctorProfilePage(),
          settings: settings,
        );
        
      case Routes.completeProfile:
        return MaterialPageRoute(
          builder: (_) => const PatientProfilePage(),
          settings: settings,
        );
        
      case Routes.findDoctor:
        return MaterialPageRoute(
          builder: (_) => const FindDoctorPage(),
          settings: settings,
        );
      
      case Routes.medicalDocuments:
        return MaterialPageRoute(
          builder: (_) => const MedicalDocumentsPage(),
          settings: settings,
        );
      
      case Routes.healthIcons:
        return MaterialPageRoute(
          builder: (_) => const HealthIconShowcase(),
          settings: settings,
        );
        
      case Routes.invitePatient:
        return MaterialPageRoute(
          builder: (_) => const InvitePatientPage(),
          settings: settings,
        );
        
      case Routes.viewInvitations:
        return MaterialPageRoute(
          builder: (_) => const ViewInvitationsPage(),
          settings: settings,
        );
        
      // Dynamic route with parameter
      default:
        if (settings.name?.startsWith('${Routes.patientDetail.split('/:')[0]}/') ?? false) {
          final patientId = settings.name?.split('/').last;
          return MaterialPageRoute(
            builder: (_) => PatientDetailPage(patientId: patientId ?? ''),
            settings: settings,
          );
        }
        
        if (settings.name?.startsWith('${Routes.chat.split('/:')[0]}/') ?? false) {
          final chatId = settings.name?.split('/').last;
          return MaterialPageRoute(
            builder: (_) => ChatPage(chatId: chatId ?? ''),
            settings: settings,
          );
        }
        
        if (settings.name?.startsWith('${Routes.appointmentDetails.split('/:')[0]}/') ?? false) {
          final appointmentId = settings.name?.split('/').last;
          return MaterialPageRoute(
            builder: (_) => AppointmentDetailsPage(appointmentId: appointmentId ?? ''),
            settings: settings,
          );
        }

        // Report related routes
        if (settings.name?.startsWith('${Routes.reportDetails.split('/:')[0]}/') ?? false) {
          final reportId = settings.name?.split('/').last;
          return MaterialPageRoute(
            builder: (_) => ReportDetailsPage(reportId: reportId ?? ''),
            settings: settings,
          );
        }

        final routeName = settings.name;
        if (routeName != null && 
            routeName.startsWith('${Routes.reviewReport.split('/:')[0]}/') && 
            routeName.contains('/review')) {
          final reportId = settings.name?.split('/')[2]; // Extract ID from /reports/:id/review
          return MaterialPageRoute(
            builder: (_) => ReportReviewPage(reportId: reportId ?? ''),
            settings: settings,
          );
        }
        
        // Default fallback route for undefined routes
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
          settings: settings,
        );
    }
  }
} 