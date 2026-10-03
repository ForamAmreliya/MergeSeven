import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ads/ads_service.dart';
import 'core/services/haptics_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_info.dart';
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

  await AppInfo.load();
  final prefs = await SharedPreferences.getInstance();
  final haptics = HapticsService();
  final ads = AdsService();
  runApp(MergeSevenApp(prefs: prefs, haptics: haptics, ads: ads));
  // The ad SDK starts only once the first frame is on screen.
  WidgetsBinding.instance.addPostFrameCallback((_) => ads.init());
}

class MergeSevenApp extends StatefulWidget {
  final SharedPreferences prefs;
  final HapticsService haptics;
  final AdsService? ads;

  const MergeSevenApp({super.key, required this.prefs, required this.haptics, this.ads});

  @override
  State<MergeSevenApp> createState() => _MergeSevenAppState();
}

class _MergeSevenAppState extends State<MergeSevenApp> with WidgetsBindingObserver {
  SharedPreferences get prefs => widget.prefs;
  HapticsService get haptics => widget.haptics;
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
  void didChangePlatformBrightness() {
    ads?.setBrightness(WidgetsBinding.instance.platformDispatcher.platformBrightness);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HapticsService>.value(value: haptics),
        Provider<AdsService>(create: (_) => ads ?? AdsService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs, haptics)),
        ChangeNotifierProvider(create: (_) => PlayerProvider(prefs)),
        ChangeNotifierProvider(create: (context) => GameProvider(prefs, context.read<PlayerProvider>(), haptics)),
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
            // Native ad templates follow the app theme; the service reloads
            // them only when the brightness actually changes.
            final brightness = Theme.of(context).brightness;
            WidgetsBinding.instance.addPostFrameCallback((_) => ads?.setBrightness(brightness));
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
