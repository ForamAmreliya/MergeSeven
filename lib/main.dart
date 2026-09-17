import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads/ads_service.dart';
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

  final ads = AdsService();
  runApp(MergeSevenApp(prefs: prefs, audio: audio, ads: ads));
  // Consent + ad SDK start once the first frame is on screen.
  WidgetsBinding.instance.addPostFrameCallback((_) => ads.init());
}

class MergeSevenApp extends StatefulWidget {
  final SharedPreferences prefs;
  final AudioService audio;
  final AdsService? ads;

  const MergeSevenApp({super.key, required this.prefs, required this.audio, this.ads});

  @override
  State<MergeSevenApp> createState() => _MergeSevenAppState();
}

class _MergeSevenAppState extends State<MergeSevenApp> with WidgetsBindingObserver {
  SharedPreferences get prefs => widget.prefs;
  AudioService get audio => widget.audio;
  AdsService? get ads => widget.ads;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) audio.stopAll();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AudioService>.value(value: audio),
        Provider<AdsService>(create: (_) => ads ?? AdsService()),
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
