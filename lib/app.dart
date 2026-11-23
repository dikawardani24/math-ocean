import 'package:flutter/material.dart';

import 'core/audio_service.dart';
import 'core/progress.dart';
import 'theme.dart';
import 'world/world_map_screen.dart';

class MathOceanApp extends StatefulWidget {
  const MathOceanApp({super.key, required this.progress});

  final ProgressController progress;

  @override
  State<MathOceanApp> createState() => _MathOceanAppState();
}

class _MathOceanAppState extends State<MathOceanApp>
    with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AudioService.instance.stopAmbience();
      AudioService.instance.stopSpeaking();
    } else if (state == AppLifecycleState.resumed &&
        widget.progress.ambienceOn) {
      AudioService.instance.startAmbience();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProgressScope(
      controller: widget.progress,
      child: MaterialApp(
        title: 'Math Ocean',
        debugShowCheckedModeBanner: false,
        theme: buildOceanTheme(),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1,
          maxScaleFactor: 1.15,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const WorldMapScreen(),
      ),
    );
  }
}
