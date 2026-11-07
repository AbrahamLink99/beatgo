/// Audio engine: sample playback via flutter_soloud + a lookahead scheduler.
///
/// Step 1 of the project is proving this feels tight enough on the phone.
/// Scheduling is done from Dart with a 25 ms tick and ~60 ms lookahead;
/// each hit is fired with a Future.delayed at its exact wall-clock time.
/// If the jitter is audible on device, the next move is a native scheduler.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../model/pattern.dart';

class AudioEngine {
  AudioEngine._();
  static final AudioEngine instance = AudioEngine._();

  final _soloud = SoLoud.instance;
  final Map<String, AudioSource> _sources = {};
  bool _ready = false;
  bool get ready => _ready;

  Future<void> init() async {
    if (_ready) return;
    await _soloud.init(sampleRate: 48000, bufferSize: 256, channels: Channels.stereo);
    _soloud.setGlobalVolume(0.9);
    _ready = true;
  }

  /// Load (and cache) a sample. Asset paths start with `assets/`,
  /// anything else is treated as a file on disk.
  Future<AudioSource?> load(String path) async {
    if (_sources.containsKey(path)) return _sources[path];
    try {
      final src = path.startsWith('assets/')
          ? await _soloud.loadAsset(path)
          : await _soloud.loadFile(path);
      _sources[path] = src;
      return src;
    } catch (e) {
      debugPrint('BeatGo: could not load $path: $e');
      return null;
    }
  }

  Future<void> preload(Pattern p) async {
    for (final t in p.tracks) {
      await load(t.samplePath);
    }
  }

  /// Fire one hit now. [semitones] pitches a melodic sample relative to its root.
  Future<void> trigger(Track t, {int semitones = 0, double velocity = 1, Duration? gate}) async {
    final src = _sources[t.samplePath] ?? await load(t.samplePath);
    if (src == null) return;
    final speed = math.pow(2, semitones / 12).toDouble();
    final vol = (t.volume * velocity).clamp(0.0, 1.0);
    final h = await _soloud.play(src, volume: vol, paused: true);
    if (semitones != 0) _soloud.setRelativePlaySpeed(h, speed);
    _soloud.setPause(h, false);
    if (gate != null) {
      Timer(gate, () {
        // Short fade instead of a hard cut.
        _soloud.fadeVolume(h, 0, const Duration(milliseconds: 30));
        Timer(const Duration(milliseconds: 40), () => _soloud.stop(h));
      });
    }
  }

  SoundHandle? _preview;

  /// Audition a file in the browser. Stops the previous preview first.
  Future<void> preview(String path) async {
    final src = await load(path);
    if (src == null) return;
    _preview = await _soloud.play(src, volume: 0.9);
  }

  Future<void> stopPreview() async {
    final h = _preview;
    _preview = null;
    if (h != null) {
      try {
        await _soloud.stop(h);
      } catch (_) {}
    }
  }

  /// Drop a cached sample (e.g. after a track changed sound).
  void unload(String path) {
    final s = _sources.remove(path);
    if (s != null) _soloud.disposeSource(s);
  }

  void dispose() {
    for (final s in _sources.values) {
      _soloud.disposeSource(s);
    }
    _sources.clear();
    _soloud.deinit();
    _ready = false;
  }
}

/// Plays a [Pattern] in a loop and reports the current step.
class Sequencer {
  Sequencer(this.engine);
  final AudioEngine engine;

  Pattern? pattern;
  final ValueNotifier<int> currentStep = ValueNotifier(-1);
  bool get playing => _timer != null;

  Timer? _timer;
  Stopwatch? _clock;
  int _nextStep = 0;
  double _nextTimeMs = 0;

  static const _tickMs = 25;
  static const _lookaheadMs = 60.0;

  double _stepMs(Pattern p) => 60000.0 / p.bpm / 4;

  double _swingOffsetMs(Pattern p, int step) =>
      step.isOdd ? _stepMs(p) * p.swing : 0;

  void start() {
    final p = pattern;
    if (p == null || playing) return;
    _clock = Stopwatch()..start();
    _nextStep = 0;
    _nextTimeMs = 80; // small start-up margin
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) => _tick(p));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _clock?.stop();
    currentStep.value = -1;
  }

  void toggle() => playing ? stop() : start();

  void _tick(Pattern p) {
    final now = _clock!.elapsedMilliseconds.toDouble();
    while (_nextTimeMs < now + _lookaheadMs) {
      final step = _nextStep;
      final fireAt = _nextTimeMs + _swingOffsetMs(p, step);
      final delay = math.max(0, fireAt - now).round();
      Timer(Duration(milliseconds: delay), () {
        currentStep.value = step;
        _fireStep(p, step);
      });
      _nextTimeMs += _stepMs(p);
      _nextStep = (_nextStep + 1) % p.steps;
    }
  }

  void _fireStep(Pattern p, int step) {
    for (final t in p.tracks) {
      if (t.muted) continue;
      for (final n in t.notes) {
        if (n.step != step) continue;
        final vel = n.velocity / 127;
        if (t.isDrum) {
          engine.trigger(t, velocity: vel);
        } else {
          final gateMs = _stepMs(p) * n.length * 0.9;
          engine.trigger(t,
              semitones: n.pitch - t.rootNote,
              velocity: vel,
              gate: Duration(milliseconds: gateMs.round()));
        }
      }
    }
  }
}
