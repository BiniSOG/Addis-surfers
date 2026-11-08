import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ad_manager.dart';
import 'audio/audio_manager.dart';
import 'progress.dart';
import 'settings.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Progress.load();
  await GameSettings.load();
  // Audio loads in the background; music starts as soon as it is ready.
  AudioManager.instance.init();
  // Silence the soundtrack while full-screen ads play.
  AdManager.instance.onFullScreenChange = (showing) =>
      showing ? AudioManager.instance.pauseMusic() : AudioManager.instance.resumeMusic();
  // Consent + SDK init run in the background; ads appear once ready.
  AdManager.instance.init();
  runApp(const AddisSurfersApp());
}

class AddisSurfersApp extends StatelessWidget {
  const AddisSurfersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Addis Surfers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF078930)),
        useMaterial3: true,
        fontFamilyFallback: const ['NotoEthiopic'],
      ),
      home: const GameScreen(),
    );
  }
}
