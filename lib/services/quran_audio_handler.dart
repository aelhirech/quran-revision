import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';

/// Runs `just_audio` behind `audio_service` so the loop started from
/// `VerseBottomSheet` keeps playing screen-locked/backgrounded, with
/// play/pause/stop reachable from the system notification (US-9 criterion
/// 3). Single global instance (unlike the other `lib/services/` classes,
/// all static): `audio_service` itself imposes this lifecycle, and the loop
/// stays purely passive — never read/written to `AppState`/`ayah_facts`
/// (US-9 criterion 4).
///
/// `audio_service`/`just_audio` have no Windows implementation: the only
/// test environment available on this machine (see
/// `docs/DOCUMENTATION_TECHNIQUE.md` §12) can't exercise real playback.
/// [initialize] swallows the failure instead of blocking app startup, and
/// [available] lets the UI cleanly disable the listen button on an
/// unsupported platform.
class QuranAudioHandler extends BaseAudioHandler {
  static late final QuranAudioHandler instance;
  static bool available = false;

  static Future<void> initialize() async {
    try {
      instance = await AudioService.init(
        builder: () => QuranAudioHandler._(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.quranrevision.audio.playback',
          androidNotificationChannelName: 'Lecture audio du Coran',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      available = true;
    } catch (e) {
      // Expected on Windows/Linux (no native implementation) — never
      // propagated, but logged to distinguish this case from a real
      // regression on a platform that's supposed to be supported.
      debugPrint('QuranAudioHandler unavailable on this platform: $e');
      available = false;
    }
  }

  /// [instance.playbackState] guarded by [available] — the single place
  /// callers need, instead of checking [available] themselves before every
  /// read of [instance].
  static Stream<PlaybackState> get playbackStateStream =>
      available ? instance.playbackState : const Stream.empty();

  /// [available] + [isLoadedFor] combined — the single check callers need
  /// instead of reading [available] themselves before touching [instance].
  static bool isCurrentlyLoaded(String mediaId) =>
      available && instance.isLoadedFor(mediaId);

  static const List<MediaControl> _pausedControls = [MediaControl.play, MediaControl.stop];
  static const List<MediaControl> _playingControls = [MediaControl.pause, MediaControl.stop];
  static const Map<ProcessingState, AudioProcessingState> _processingStates = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  final AudioPlayer _player = AudioPlayer();

  QuranAudioHandler._() {
    _player.playbackEventStream.listen(_broadcastState);
  }

  Stream<bool> get playingStream => _player.playingStream;
  bool get playing => _player.playing;

  /// Centralizes the "is this range the one currently loaded?" comparison —
  /// avoids rebuilding `mediaItem.valueOrNull?.id == id` at every UI call
  /// site.
  bool isLoadedFor(String mediaId) => mediaItem.valueOrNull?.id == mediaId;

  /// Plays [urls] (one mp3 per verse) in a continuous loop, under [item]'s
  /// label (surah/reciter name shown on the lockscreen). Never touches
  /// `ayah_facts` — purely passive.
  Future<void> playLoop({required List<String> urls, required MediaItem item}) async {
    mediaItem.add(item);
    await _player.setAudioSources(
      [for (final u in urls) AudioSource.uri(Uri.parse(u))],
    );
    await _player.setLoopMode(LoopMode.all);
    await _player.play();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: playing ? _playingControls : _pausedControls,
      systemActions: const {MediaAction.play, MediaAction.pause, MediaAction.stop},
      processingState: _processingStates[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
    ));
  }
}
