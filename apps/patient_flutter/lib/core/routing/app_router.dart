import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/splash/presentation/welcome_screen.dart';
import '../../features/auth/presentation/signin_screen.dart';
import '../../features/registration/presentation/registration_screen.dart';
import '../../features/registration/presentation/phone_entry_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/institution_home/presentation/institution_home_screen.dart';
import '../../features/otp_verification/presentation/otp_verification_screen.dart';
import '../../features/identity_generation/presentation/identity_generation_screen.dart';
import '../../features/onboarding/presentation/complete_profile_screen.dart';
import '../../features/patient_layout/patient_layout.dart';
import '../../features/patient_home/presentation/patient_home_screen.dart';
import '../../features/card/presentation/card_view_screen.dart';
import '../../features/medical_booklet/presentation/medical_booklet_screen.dart';
import '../../features/medical_consultation/presentation/medical_consultation_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_thread_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/health_journey/presentation/health_journey_screen.dart';
import '../../features/access_dashboard/presentation/access_dashboard_screen.dart';
import '../../features/audit_log/presentation/audit_log_screen.dart';
import '../../features/doctor_search/presentation/doctor_search_screen.dart';
import '../../features/doctor_profile/presentation/doctor_profile_screen.dart';
import '../../features/appointments/presentation/booking_screen.dart';
import '../../features/emergency_mode/presentation/emergency_mode_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/card_management/presentation/card_management_screen.dart';
import '../../features/prescriptions/presentation/prescriptions_screen.dart';
import '../../features/payment/presentation/payment_screen.dart';
import '../../features/appointments/presentation/appointments_screen.dart';
import '../../features/appointments/presentation/appointment_detail_screen.dart';
import '../../features/appointments/presentation/reschedule_screen.dart';
import '../../shared/models/doctor_profile.dart';

/// Bridges Riverpod auth state changes into a [Listenable] that go_router can
/// observe via [GoRouter.refreshListenable], so the [GoRouter.redirect] guard
/// re-evaluates the moment authentication status flips.
class _AuthListenable extends ChangeNotifier {
  void notifyChange() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  // Routes reachable without an authenticated session (registration/onboarding
  // are driven by the screens; onboarding is reached only after register sets
  // the authenticated state, but must not be yanked away mid-flow).
  const publicRoutes = <String>{
    '/',
    '/register',
    '/signin',
    '/welcome',
    '/otp',
    '/onboarding',
    '/onboarding/identity-generation',
    '/onboarding/personal-info',
    '/onboarding/complete-profile',
  };

  final authListenable = _AuthListenable();
  ref.listen(authProvider, (_, _) => authListenable.notifyChange());

  return GoRouter(
    initialLocation: '/',
    // Re-evaluate navigation whenever the auth state changes so a protected
    // screen can never mount before authentication is established.
    refreshListenable: authListenable,
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final loc = state.matchedLocation;
      final isPublic = publicRoutes.contains(loc);

      // While the session is being established/refreshed, do not allow a
      // protected screen to mount. Stay where we are (or fall back to splash).
      if (status == AuthStatus.initial ||
          status == AuthStatus.refreshing ||
          status == AuthStatus.loading) {
        return isPublic ? null : '/';
      }

      if (status == AuthStatus.authenticated) {
        // An authenticated user with an incomplete profile must finish onboarding
        // before reaching the dashboard. This covers login/sign-in users whose
        // patient record is still a stub (no DOB/gender/city). The two onboarding
        // screens are whitelisted so they are not bounced away mid-flow.
        final needsOnboarding = ref.read(authProvider).needsOnboarding;
        if (needsOnboarding &&
            loc != '/otp' &&
            loc != '/onboarding/identity-generation' &&
            loc != '/onboarding/personal-info' &&
            loc != '/onboarding/complete-profile') {
          return '/onboarding/complete-profile';
        }
        // Send entry/auth screens straight to the dashboard — EXCEPT /otp, which
        // is the registration hand-off. After OTP verification the screen pushes
        // to /onboarding/identity-generation to complete onboarding; redirecting
        // /otp to home here would race ahead of that push and skip onboarding,
        // leaving every registered user with a blank (stub) profile.
        if (loc == '/' ||
            loc == '/signin' ||
            loc == '/register') {
          return '/patient/home';
        }
        return null; // protected route or onboarding — allowed to stay
      }

      // unauthenticated / error: protected routes require login.
      if (!isPublic) return '/signin';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const PhoneEntryScreen(),
      ),
      GoRoute(
        path: '/onboarding/personal-info',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final phone = extra?['phone'] as String?;
          return RegistrationScreen(initialPhone: phone);
        },
      ),
      GoRoute(
        path: '/signin',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpVerificationScreen(
            registrationData: extra?['registrationData'] as Map<String, dynamic>?,
          );
        },
      ),
      GoRoute(
        path: '/onboarding/identity-generation',
        builder: (context, state) => const IdentityGenerationScreen(),
      ),
      GoRoute(
        path: '/onboarding/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/institution/home',
        builder: (context, state) => const InstitutionHomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PatientLayout(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/home',
                builder: (context, state) => const PatientHomeScreen(),
              ),
              GoRoute(
                path: '/patient/notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: '/patient/journey',
                builder: (context, state) => const HealthJourneyScreen(),
              ),
              GoRoute(
                path: '/patient/doctor-search',
                builder: (context, state) => const DoctorSearchScreen(),
              ),
              GoRoute(
                path: '/patient/doctor-profile',
                builder: (context, state) {
                  final doctor = state.extra as DoctorProfile?;
                  return DoctorProfileScreen(doctor: doctor ?? DoctorProfile(
                    id: '',
                    name: 'Inconnu',
                    specialty: '',
                    bio: '',
                    hospital: '',
                    hospitalLocation: '',
                    nextAvailableSlot: '',
                  ));
                },
              ),
              GoRoute(
                path: '/patient/booking',
                builder: (context, state) {
                  final doctor = state.extra as DoctorProfile?;
                  return BookingScreen(doctor: doctor ?? DoctorProfile(
                    id: '',
                    name: 'Inconnu',
                    specialty: '',
                    bio: '',
                    hospital: '',
                    hospitalLocation: '',
                    nextAvailableSlot: '',
                  ));
                },
              ),
              GoRoute(
                path: '/patient/payment',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return PaymentScreen(
                    doctorName: extra?['doctorName'] as String? ?? '',
                    specialty: extra?['specialty'] as String? ?? '',
                    location: extra?['location'] as String? ?? '',
                    date: extra?['date'] as String? ?? '',
                    doctorId: extra?['doctorId'] as String? ?? '',
                    startTime: extra?['startTime'] as String? ?? '',
                    endTime: extra?['endTime'] as String? ?? '',
                    reason: extra?['reason'] as String? ?? '',
                  );
                },
              ),
              GoRoute(
                path: '/patient/access',
                builder: (context, state) => const AccessDashboardScreen(),
              ),
              GoRoute(
                path: '/patient/audit',
                builder: (context, state) => const AuditLogScreen(),
              ),
              GoRoute(
                path: '/patient/card',
                builder: (context, state) => const CardViewScreen(),
                routes: [
                  GoRoute(
                    path: 'manage',
                    builder: (context, state) => const CardManagementScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/patient/emergency',
                builder: (context, state) => const EmergencyModeScreen(),
              ),
              GoRoute(
                path: '/patient/appointments',
                builder: (context, state) => const AppointmentsScreen(),
              ),
              GoRoute(
                path: '/appointment/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return AppointmentDetailScreen(appointmentId: id);
                },
              ),
              GoRoute(
                path: '/appointment/:id/reschedule',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  final extra = state.extra as Map<String, dynamic>?;
                  return RescheduleScreen(
                    appointmentId: id,
                    doctorId: extra?['doctorId'] as String? ?? '',
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/booklet',
                builder: (context, state) => const MedicalBookletScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return MedicalConsultationScreen(entryId: id);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/patient/recipes',
                builder: (context, state) => const PrescriptionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/chat',
                builder: (context, state) => const ChatListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'] ?? '';
                      return ChatThreadScreen(chatId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: '/patient/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});