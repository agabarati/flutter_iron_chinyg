// lib/services/audio_service_factory.dart
import 'package:audio_service/audio_service.dart';
import 'audio_player_service.dart';

AudioPlayerService getAudioPlayerService() {
  return AudioPlayerService.instance;
}
