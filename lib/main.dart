import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'presentation/themes/app_theme.dart';
import 'presentation/pages/home_page.dart';
import 'services/audio_player_service.dart';
import 'data/repositories/part_cache_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация just_audio_background
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.flutter_iron_chinyg.audio',
    androidNotificationChannelName: 'Ирон чиныг',
    androidNotificationOngoing: true,
    // notificationColor: 0xFF8B1E3F,
  );

  // // Инициализация AudioService с синглтоном
  // await AudioService.init(
  //   builder: () => AudioPlayerService.instance,
  //   config: AudioServiceConfig(
  //     androidNotificationChannelId: 'com.example.flutter_iron_chinyg.audio',
  //     androidNotificationChannelName: 'Ирон чиныг',
  //     androidNotificationOngoing: true,
  //     // notificationColor: 0xFF8B1E3F,
  //   ),
  // );

  // Устанавливаем репозиторий для кэширования частей
  final partCacheRepo = PartCacheRepository();
  AudioPlayerService.instance.setPartCacheRepository(partCacheRepo);

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
