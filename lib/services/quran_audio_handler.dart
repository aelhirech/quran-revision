import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';

typedef AudioLoop = ({String reciterId, int surahId, int start, int end});

/// Runs `just_audio` behind `audio_service` so the loop started from
/// `VerseAudioBar` keeps playing screen-locked/backgrounded, with
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

  /// The loop last started by [playLoop], null once stopped (or on an
  /// unsupported platform) — lets a reopened view recognize a sub-portion it
  /// started earlier, which an opaque mediaId comparison could not.
  static AudioLoop? get currentLoop => available ? instance._loop : null;

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
  AudioLoop? _loop;

  QuranAudioHandler._() {
    _player.playbackEventStream.listen(_broadcastState);
  }

  Stream<bool> get playingStream => _player.playingStream;
  bool get playing => _player.playing;

  /// Plays [sources] (one mp3 per verse, remote or local `file://`) of [loop]
  /// in a continuous loop, under [item]'s label (surah/reciter name shown on
  /// the lockscreen). Returns once playback has started. Never touches
  /// `ayah_facts` — purely passive.
  Future<void> playLoop({
    required AudioLoop loop,
    required List<Uri> sources,
    required MediaItem item,
  }) async {
    // The previous playlist is gone as soon as it is replaced: a failure
    // below must not leave it advertised as the current loop.
    _loop = null;
    mediaItem.add(item);
    await _player.setAudioSources(
      [for (final u in sources) AudioSource.uri(u)],
    );
    await _player.setLoopMode(LoopMode.all);
    _loop = loop;
    // just_audio's play() only completes on pause/stop: awaiting it would
    // keep the caller's "starting" state on for the whole playback. Its error
    // no longer reaches the caller, so log it and drop the dead loop.
    unawaited(_player.play().catchError((Object e) {
      debugPrint('QuranAudioHandler play failed: $e');
      if (_loop == loop) _loop = null;
    }));
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _loop = null;
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
