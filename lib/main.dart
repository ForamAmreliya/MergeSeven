import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/game_provider.dart';
import 'providers/player_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent),
  );

  final prefs = await SharedPreferences.getInstance();
  final audio = AudioService();
  audio.init(); // preloads in the background; sounds become available as they load

  runApp(MergeSevenApp(prefs: prefs, audio: audio));
}

class MergeSevenApp extends StatelessWidget {
  final SharedPreferences prefs;
  final AudioService audio;

  const MergeSevenApp({super.key, required this.prefs, required this.audio});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AudioService>.value(value: audio),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs, audio)),
        ChangeNotifierProvider(create: (_) => PlayerProvider(prefs)),
        ChangeNotifierProvider(create: (context) => GameProvider(prefs, context.read<PlayerProvider>(), audio)),
      ],
      child: Selector<SettingsProvider, ThemeMode>(
        selector: (_, s) => s.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'MergeSeven',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 400),
          builder: (context, child) {
            // Keep the game layout stable when the system font is very large.
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: Theme.of(context).brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
                child: child!,
              ),
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
