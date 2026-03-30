// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'presentation/themes/app_theme.dart';
import 'presentation/pages/home_page.dart';

void main() async {
  // Обязательно для инициализации плагинов
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация фонового воспроизведения
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.flutter_iron_chinyg.audio',
    androidNotificationChannelName: 'Ирон чиныг',
    androidNotificationOngoing: true,
    // notificationColor: 0xFF8B1E3F, // Бордовый цвет в hex
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ирон чиныг',
      theme: AppTheme.lightTheme,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
