import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/database/local_database.dart';
import 'core/data/repositories/repository_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final container = ProviderContainer();
  final db = container.read(localDatabaseProvider);
  await db.init();
  await container.read(syncQueueProvider).init();
  container.read(coordinatorProvider).synchronize();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TosumoApp(),
    ),
  );
}

class TosumoApp extends ConsumerStatefulWidget {
  const TosumoApp({super.key});

  @override
  ConsumerState<TosumoApp> createState() => _TosumoAppState();
}

class _TosumoAppState extends ConsumerState<TosumoApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TOSUMO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale?.languageCode) {
            return supported;
          }
        }
        return supportedLocales.first;
      },
    );
  }
}
