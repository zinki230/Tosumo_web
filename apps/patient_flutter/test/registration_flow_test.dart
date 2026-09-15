import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tosumo_patient/core/network/api_client.dart';
import 'package:tosumo_patient/core/network/auth_providers.dart';
import 'package:tosumo_patient/core/network/auth_service.dart';
import 'package:tosumo_patient/core/network/token_manager.dart';
import 'package:tosumo_patient/core/routing/app_router.dart';
import 'package:tosumo_patient/core/utils/localization.dart';

AppLocalization? _loc;

/// Fake auth service that short-circuits the phone availability check so the
/// widget tests never touch the network.
class _FakeAuthService extends AuthService {
  _FakeAuthService({required this.phoneExists})
      : super(
          ApiClient(
            tokenManager: TokenManager(const FlutterSecureStorage()),
          ),
          TokenManager(const FlutterSecureStorage()),
        );

  final bool phoneExists;

  @override
  Future<bool> phoneAlreadyRegistered({required String phone}) async =>
      phoneExists;
}

Future<GoRouter> _buildHarness(WidgetTester tester, bool phoneExists) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final loc = _loc ??= (await tester.runAsync(() => AppLocalization.load('fr')))!;
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(
        _FakeAuthService(phoneExists: phoneExists),
      ),
      localizationProvider.overrideWith(
        (ref, arg) => SynchronousFuture<AppLocalization>(loc),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  router.go('/register');
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
  return router;
}

Future<void> _fillForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), '691234567');
  await tester.enterText(find.byType(TextField).at(1), 'Alain');
  await tester.enterText(find.byType(TextField).at(2), 'Foka');
  await tester.tap(find.text('Masculin'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(3), '23');
  await tester.enterText(find.byType(TextField).at(4), '11');
  await tester.enterText(find.byType(TextField).at(5), '2000');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('registration steps are nested: OTP back returns to the filled form', (tester) async {
    final router = await _buildHarness(tester, false);
    expect(router.state.uri.toString(), '/register');

    await _fillForm(tester);
    await tester.ensureVisible(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/otp');

    router.pop();
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/register');
    expect(find.text('Alain'), findsOneWidget);
    expect(find.text('Foka'), findsOneWidget);
  });

  testWidgets('duplicate phone keeps the user on the phone step with error and login CTA', (tester) async {
    final router = await _buildHarness(tester, true);
    expect(router.state.uri.toString(), '/register');

    await _fillForm(tester);
    await tester.ensureVisible(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), '/register');
    expect(
      find.text('Ce numéro est déjà utilisé. Veuillez vous connecter ou utiliser un autre numéro.'),
      findsOneWidget,
    );
    expect(find.text('Se connecter'), findsOneWidget);
  });
}