import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:tosumo_patient/core/data/response_mapper.dart';
import 'package:tosumo_patient/core/network/online_status.dart';
import 'package:tosumo_patient/core/routing/app_router.dart';
import 'package:tosumo_patient/core/utils/localization.dart';
import 'package:tosumo_patient/features/auth/providers/auth_provider.dart';
import 'package:tosumo_patient/features/patient/providers/patient_provider.dart';
import 'package:tosumo_patient/shared/models/card_model.dart';
import 'package:tosumo_patient/shared/models/chat_conversation.dart';
import 'package:tosumo_patient/shared/models/notification_model.dart';
import 'package:tosumo_patient/shared/models/patient.dart';
import 'package:tosumo_patient/shared/models/booklet_entry.dart';

String _location(GoRouter router) => router.state.uri.toString();

const _backIcon = LucideIcons.arrowLeft;

AppLocalization? locStore;

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      status: AuthStatus.authenticated,
      role: 'patient',
    );
  }

  @override
  Future<void> tryAutoLogin() async {}
}

class _FakeSyncStatus extends SyncStatusNotifier {
  @override
  SyncStatus build() => SyncStatus.online;

  @override
  Future<void> start() async {}
}

class _FakePatientNotifier extends PatientNotifier {
  @override
  PatientState build() {
    final now = DateTime.now();
    return PatientState(
      patientId: 'p1',
      patient: Patient(
        id: 'p1',
        name: 'Test Patient',
        dateOfBirth: '1990-01-01',
        nationalId: 'CM-0001',
        contactInfo: const ContactInfo(
          phone: '+237 600 000 000',
          email: 'test@tosumo.cm',
        ),
        bloodType: 'O+',
        emergencyContact: const EmergencyContact(
          name: 'Next Of Kin',
          relationship: 'Spouse',
          phone: '+237 600 000 001',
        ),
      ),
      card: CardModel(
        patientId: 'p1',
        token: 'MC-0000-0001-0002',
        issuedAt: now.toIso8601String(),
      ),
      appointments: [
        Appointment(
          id: 'appt-1',
          doctorName: 'Dr. Jean Mbarga',
          specialty: 'Cardiologist',
          location: 'Yaounde',
          date: now.add(const Duration(days: 2)).toIso8601String(),
          doctorId: 'doc-1',
          status: 'pending',
          startTime: '09:00',
        ),
      ],
      notifications: [
        NotificationModel(
          id: 'n1',
          type: 'appointment',
          title: 'Rappel',
          message: 'Votre rendez-vous approche',
          time: now.toIso8601String(),
          read: false,
        ),
      ],
      chats: [
        ChatConversation(
          id: 'chat-1',
          participantName: 'Dr. Jean Mbarga',
          participantRole: 'Cardiologist',
          participantInitials: 'JM',
          lastMessage: 'Bonjour',
          lastMessageDate: now.toIso8601String(),
          unread: 1,
          online: true,
          messages: [
            ChatMessage(
              id: 'm1',
              senderId: 'doc-1',
              senderName: 'Dr. Jean Mbarga',
              text: 'Bonjour',
              timestamp: now.toIso8601String(),
            ),
          ],
        ),
      ],
      bookletEntries: [
        BookletEntry(
          id: 'entry-1',
          patientId: 'p1',
          visitDate: now.subtract(const Duration(days: 14)).toIso8601String(),
          facility: 'Hôpital Central de Yaoundé',
          summary: 'Consultation cardiaque — suivi de l\'hypertension',
          details: 'Détails complets de la consultation de cardiologie.',
          doctorName: 'Dr. Jean Mbarga',
          doctorSpecialty: 'Cardiologie',
          diagnosis: 'Hypertension artérielle stabilisée',
          status: 'completed',
          consultationType: 'Consultation',
          prescription: 'Amlodipine 5mg',
          symptoms: 'Céphalées occasionnelles',
          doctorNotes: 'Poursuivre le traitement habituel.',
        ),
      ],
      loading: false,
    );
  }

  @override
  Future<void> loadPatientData(String patientId) async {}

  @override
  Future<void> loadAppointments() async {}

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<void> markNotificationRead(String id) async {}

  @override
  Future<void> markChatAsRead(String chatId) async {}

  @override
  Future<ChatConversation?> refreshChat(String chatId) async {
    return state.chats.where((c) => c.id == chatId).firstOrNull;
  }

  @override
  Future<void> sendChatMessage(String chatId, String content) async {}

  @override
  Future<void> appendIncomingMessage(String chatId, ChatMessage message) async {}
}

Future<(ProviderContainer, GoRouter)> _buildHarness(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final loc = locStore ??= (await tester.runAsync(() => AppLocalization.load('fr')))!;
  final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(_FakeAuthNotifier.new),
      syncStatusProvider.overrideWith(_FakeSyncStatus.new),
      patientProvider.overrideWith(_FakePatientNotifier.new),
      localizationProvider.overrideWith(
        (ref, arg) => SynchronousFuture<AppLocalization>(loc),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.go('/patient/home');
  await tester.pumpAndSettle();
  return (container, router);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});


  testWidgets('Home > Card tile pushes, back returns to Home', (tester) async {
    final (_, router) = await _buildHarness(tester);
    expect(_location(router), '/patient/home');

    await _tapVisible(tester, find.text('Carte Médicale'));
    expect(_location(router), '/patient/card');
    expect(find.text('Votre carte d\'identité médicale'), findsOneWidget);

    await _tapVisible(tester, find.byIcon(_backIcon).first);
    expect(_location(router), '/patient/home');
    expect(find.text('Carte Médicale'), findsOneWidget);
  });

  testWidgets('Home > Notifications bell pushes, back returns to Home', (tester) async {
    final (_, router) = await _buildHarness(tester);

    await _tapVisible(tester, find.byIcon(LucideIcons.bell).first);
    expect(_location(router), '/patient/notifications');

    await _tapVisible(tester, find.byIcon(_backIcon).last);
    expect(_location(router), '/patient/home');
  });

  testWidgets('Home > Booklet tile pushes, back returns to Home', (tester) async {
    final (_, router) = await _buildHarness(tester);

    await _tapVisible(tester, find.text('Carnet Médical'));
    expect(_location(router), '/patient/booklet');

    router.pop();
    await tester.pumpAndSettle();
    expect(_location(router), '/patient/home');
  });

  testWidgets('Home > Tout voir pushes Appointments, back returns to Home', (tester) async {
    final (_, router) = await _buildHarness(tester);

    await _tapVisible(tester, find.text('Tout voir'));
    expect(_location(router), '/patient/appointments');
    expect(find.text('Rendez-vous'), findsOneWidget);

    await _tapVisible(tester, find.byIcon(_backIcon).first);
    expect(_location(router), '/patient/home');
  });

  testWidgets('Appointments empty action pushes Doctor Search, back returns to Appointments', (tester) async {
    final (_, router) = await _buildHarness(tester);
    router.go('/patient/appointments');
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Passés'));
    await _tapVisible(tester, find.text('Prendre un rendez-vous'));
    expect(_location(router), '/patient/doctor-search');

    router.pop();
    await tester.pumpAndSettle();
    expect(_location(router), '/patient/appointments');
  });

  testWidgets('Chat thread back returns to Chat list', (tester) async {
    final (_, router) = await _buildHarness(tester);
    router.go('/patient/chat');
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text('Dr. Jean Mbarga'));
    expect(_location(router), '/patient/chat/chat-1');

    await _tapVisible(tester, find.byIcon(_backIcon).first);
    expect(_location(router), '/patient/chat');
  });

  testWidgets('Booklet > Consultation pushes, back returns to Booklet', (tester) async {
    final (_, router) = await _buildHarness(tester);

    await _tapVisible(tester, find.text('Carnet Médical'));
    expect(_location(router), '/patient/booklet');

    await _tapVisible(tester, find.textContaining('Hôpital Central de Yaoundé'));
    expect(_location(router), '/patient/booklet/entry-1');
    expect(find.text('Consultation'), findsWidgets);

    await _tapVisible(tester, find.byIcon(_backIcon).first);
    expect(_location(router), '/patient/booklet');
  });

  testWidgets('Profile > Settings pushes, back returns to Profile', (tester) async {
    final (_, router) = await _buildHarness(tester);

    await _tapVisible(tester, find.byIcon(LucideIcons.user));
    expect(_location(router), '/patient/profile');

    await tester.scrollUntilVisible(
      find.text('Paramètres'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Paramètres'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_location(router), '/patient/settings');

    router.pop();
    await tester.pumpAndSettle();
    expect(_location(router), '/patient/profile');
  });

  testWidgets('Tab switch preserves nested history; Back pops previous screen not exit', (tester) async {
    final (_, router) = await _buildHarness(tester);

    await _tapVisible(tester, find.text('Tout voir'));
    expect(_location(router), '/patient/appointments');

    await _tapVisible(tester, find.byIcon(LucideIcons.home));
    expect(_location(router), '/patient/home');

    await _tapVisible(tester, find.text('Tout voir'));
    expect(_location(router), '/patient/appointments');

    router.pop();
    await tester.pumpAndSettle();
    expect(_location(router), '/patient/home');
    expect(find.text('Mes rendez-vous'), findsOneWidget);
  });
}