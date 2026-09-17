import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/patients/presentation/patient_list_screen.dart';
import '../../features/patients/presentation/patient_detail_screen.dart';
import '../../features/patients/presentation/patient_vitals_edit_screen.dart';
import '../../features/patients/presentation/record_detail_screen.dart';
import '../../features/patients/presentation/record_card.dart';
import '../../domain/models/patient_detail.dart';
import '../../features/consultations/presentation/consultations_screen.dart';
import '../../domain/models/patient_summary.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/prescriptions/presentation/prescriptions_screen.dart';
import '../../features/prescriptions/presentation/prescription_detail_screen.dart';
import '../../domain/models/prescription.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/emergency/presentation/emergency_screen.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/laboratory/presentation/lab_requests_screen.dart';
import '../../features/imaging/presentation/imaging_requests_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/availability/presentation/availability_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/doctor_layout/doctor_layout.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            DoctorLayout(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/analytics',
                builder: (context, state) => const AnalyticsScreen(),
              ),
              GoRoute(
                path: '/availability',
                builder: (context, state) => const AvailabilityScreen(),
              ),
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: '/emergency',
                builder: (context, state) => const EmergencyScreen(),
              ),
              GoRoute(
                path: '/lab-requests',
                builder: (context, state) => const LabRequestsScreen(),
              ),
              GoRoute(
                path: '/imaging-requests',
                builder: (context, state) => const ImagingRequestsScreen(),
              ),
              GoRoute(
                path: '/prescriptions',
                builder: (context, state) => PrescriptionsScreen(
                  initialPatient: state.extra is PatientSummary ? state.extra as PatientSummary : null,
                ),
              ),
              GoRoute(
                path: '/prescriptions/:id',
                builder: (context, state) {
                  final extra = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
                  final prescription = extra?['prescription'];
                  final patientName = extra?['patientName'] as String? ?? '';
                  if (prescription is Prescription) {
                    return PrescriptionDetailScreen(
                      prescription: prescription,
                      patientName: patientName,
                    );
                  }
                  return const PrescriptionsScreen();
                },
              ),
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
              GoRoute(
                path: '/consultations',
                builder: (context, state) => ConsultationsScreen(
                  initialPatient: state.extra is PatientSummary ? state.extra as PatientSummary : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patients',
                builder: (context, state) => const PatientListScreen(),
              ),
              GoRoute(
                path: '/patient/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return PatientDetailScreen(patientId: id);
                },
              ),
              GoRoute(
                path: '/patients/:id/vitals',
                builder: (context, state) {
                  final patient = state.extra is PatientDetail ? state.extra as PatientDetail : null;
                  if (patient == null) return const SizedBox.shrink();
                  return PatientVitalsEditScreen(patient: patient);
                },
              ),
              GoRoute(
                path: '/patients/:id/record',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  final record = extra?['record'];
                  final type = extra?['type'] as RecordType? ?? RecordType.consultation;
                  if (record == null) return const SizedBox.shrink();
                  return RecordDetailScreen(record: record, type: type);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scan',
                builder: (context, state) => const ScanScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/appointments',
                builder: (context, state) => AppointmentsScreen(
                  initialTab: state.extra is String ? state.extra as String : null,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
