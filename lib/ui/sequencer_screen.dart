import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/engine.dart';
import '../main.dart';
import '../model/pattern.dart';
import 'sample_browser.dart';
import 'track_lane.dart';

/// Bundled sounds a new track can start from.
const _assetSamples = <String, (String, TrackKind, int)>{
  'Kick': ('assets/samples/kick.wav', TrackKind.drum, 36),
  'Clap': ('assets/samples/clap.wav', TrackKind.drum, 38),
  'Closed hat': ('assets/samples/hat_closed.wav', TrackKind.drum, 42),
  'Open hat': ('assets/samples/hat_open.wav', TrackKind.drum, 46),
  'Shaker': ('assets/samples/shaker.wav', TrackKind.drum, 37),
  'Bass': ('assets/samples/bass_c1.wav', TrackKind.melodic, 24),
};

class SequencerScreen extends StatefulWidget {
  const SequencerScreen({super.key});
  @override
  State<SequencerScreen> createState() => _SequencerScreenState();
}

class _SequencerScreenState extends State<SequencerScreen> {
  final engine = AudioEngine.instance;
  late final Sequencer seq = Sequencer(engine);
  Pattern pattern = Pattern.demo();
  String status = 'Startar ljud…';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pattern');
      if (saved != null) {
        pattern = Pattern.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {}
    try {
      await engine.init();
      await engine.preload(pattern);
      seq.pattern = pattern;
      setState(() => status = '');
    } catch (e) {
      setState(() => status = 'Ljudmotorn startade inte: $e');
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pattern', jsonEncode(pattern.toJson()));
    } catch (_) {}
  }

  void _edit(void Function() f) {
    setState(f);
    _save();
  }

  // --- note editing -------------------------------------------------------

  void _tapStep(Track t, int step) {
    final existing = t.noteAt(step);
    _edit(() {
      if (existing != null) {
        t.notes.remove(existing);
      } else {
        final pitch = t.isDrum ? t.rootNote : _lastPitch(t);
        t.notes.add(Note(step: step, pitch: pitch, length: t.isDrum ? 1 : 2));
        if (!seq.playing) {
          engine.trigger(t,
              semitones: t.isDrum ? 0 : pitch - t.rootNote,
              gate: t.isDrum ? null : const Duration(milliseconds: 250));
        }
      }
    });
  }

  /// Long press: drums → cycle velocity (accent/normal/soft);
  /// melodic → step the pitch up through the scale (wraps after an octave).
  void _longPressStep(Track t, int step) {
    final n = t.noteAt(step);
    if (n == null) return;
    _edit(() {
      final i = t.notes.indexOf(n);
      if (t.isDrum) {
        final next = n.velocity >= 120 ? 60 : (n.velocity >= 100 ? 120 : 100);
        t.notes[i] = n.copyWith(velocity: next);
      } else {
        final root = 36 + pattern.keyRoot;
        final degrees = scales[pattern.scale]!;
        final rel = (n.pitch - root).clamp(0, 12);
        final nextDeg = degrees.firstWhere((d) => d > rel, orElse: () => -1);
        final newPitch = nextDeg == -1 ? root : root + nextDeg;
        t.notes[i] = n.copyWith(pitch: newPitch);
        if (!seq.playing) {
          engine.trigger(t,
              semitones: newPitch - t.rootNote,
              gate: const Duration(milliseconds: 250));
        }
      }
    });
  }

  /// Drum tracks: move the pad note (and every hit with it).
  /// Melodic tracks: tell the sampler which note the file was recorded at.
  void _shiftRoot(Track t, int delta) {
    final next = (t.rootNote + delta).clamp(0, 108);
    if (t.isDrum) {
      for (var i = 0; i < t.notes.length; i++) {
        t.notes[i] = t.notes[i].copyWith(pitch: next);
      }
    }
    t.rootNote = next;
  }

  int _lastPitch(Track t) =>
      t.notes.isEmpty ? 36 + pattern.keyRoot : t.notes.last.pitch;

  // --- tracks ---------------------------------------------------------------

  static const _fromPhone = '__phone__';

  /// Guess drum vs melodic from the file name (Splice names are descriptive).
  static TrackKind _guessKind(String name) {
    final n = name.toLowerCase();
    const melodic = ['bass', 'sub', 'synth', 'key', 'pad', 'chord', 'stab', 'lead', 'pluck', 'organ', 'piano', 'vocal', 'vox'];
    return melodic.any(n.contains) ? TrackKind.melodic : TrackKind.drum;
  }

  /// Splice-style file names often end in the root note, e.g. "…_F#min.wav" or "…_C2.wav".
  static int _guessRoot(String name, TrackKind kind) {
    if (kind == TrackKind.drum) return 36;
    final m = RegExp(r'[_\- ]([A-G])(#|b)?(-?\d)?(?=[_\-. ]|$)', caseSensitive: false).allMatches(name).lastOrNull;
    if (m == null) return 36; // C1
    var semi = const {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}[m.group(1)!.toUpperCase()]!;
    if (m.group(2) == '#') semi++;
    if (m.group(2) == 'b') semi--;
    final oct = int.tryParse(m.group(3) ?? '') ?? 1;
    return (oct + 2) * 12 + semi;
  }

  Future<void> _pickFromPhone({Track? replace}) async {
    final f = await SampleBrowser.open(context, title: replace == null ? 'Nytt spår från telefonen' : 'Byt ljud: ${replace.name}');
    if (f == null) return;
    final src = await engine.load(f.path);
    if (src == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kunde inte läsa ljudfilen')));
      }
      return;
    }
    if (replace != null) {
      _edit(() {
        replace.samplePath = f.path;
        replace.name = _shortName(f.name);
      });
    } else {
      final kind = _guessKind(f.name);
      _edit(() => pattern.tracks.add(Track(
            name: _shortName(f.name),
            kind: kind,
            samplePath: f.path,
            rootNote: _guessRoot(f.name, kind),
          )));
    }
  }

  static String _shortName(String n) {
    // "SPLICE_Pack_kick_punchy_01" → "kick punchy 01"
    final cleaned = n.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return cleaned.length > 18 ? cleaned.substring(0, 18) : cleaned;
  }

  Future<void> _addTrack() async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Bg.lane,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('Nytt spår', style: TextStyle(color: Bg.muted, letterSpacing: 1.2, fontSize: 12)),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open, color: Bg.lime),
            title: const Text('Från telefonen…', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Download/Splice, Music, egna mappar', style: TextStyle(color: Bg.muted, fontSize: 12)),
            onTap: () => Navigator.pop(context, _fromPhone),
          ),
          const Divider(color: Bg.line, height: 8),
          for (final e in _assetSamples.entries)
            ListTile(
              title: Text(e.key),
              subtitle: Text(e.value.$2 == TrackKind.drum ? 'trumma · ${noteName(e.value.$3)}' : 'melodisk · sample på ${noteName(e.value.$3)}',
                  style: const TextStyle(color: Bg.muted, fontSize: 12)),
              onTap: () => Navigator.pop(context, e.key),
            ),
        ],
      ),
    );
    if (pick == null) return;
    if (pick == _fromPhone) {
      await _pickFromPhone();
      return;
    }
    final (path, kind, root) = _assetSamples[pick]!;
    final t = Track(name: pick, kind: kind, samplePath: path, rootNote: root);
    await engine.load(path);
    _edit(() => pattern.tracks.add(t));
  }

  void _trackMenu(Track t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Bg.lane,
      builder: (_) => StatefulBuilder(builder: (context, setSheet) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              t.samplePath.startsWith('assets/') ? 'inbyggt ljud' : t.samplePath.replaceFirst('/storage/emulated/0/', ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Bg.muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Row(children: [
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  _pickFromPhone(replace: t);
                },
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Byt ljud'),
              ),
              const SizedBox(width: 10),
              SegmentedButton<TrackKind>(
                segments: const [
                  ButtonSegment(value: TrackKind.drum, label: Text('Trumma')),
                  ButtonSegment(value: TrackKind.melodic, label: Text('Melodisk')),
                ],
                selected: {t.kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  _edit(() {
                    t.kind = s.first;
                    if (t.isDrum) {
                      for (var i = 0; i < t.notes.length; i++) {
                        t.notes[i] = t.notes[i].copyWith(pitch: t.rootNote, length: 1);
                      }
                    }
                  });
                  setSheet(() {});
                },
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text(t.isDrum ? 'MIDI-not (Drum Rack-pad)' : 'Samplens grundton',
                  style: const TextStyle(color: Bg.muted)),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _edit(() => _shiftRoot(t, -1));
                  setSheet(() {});
                },
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 44,
                child: Text(noteName(t.rootNote), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () {
                  _edit(() => _shiftRoot(t, 1));
                  setSheet(() {});
                },
                icon: const Icon(Icons.add),
              ),
            ]),
            Row(children: [
              const Text('Volym', style: TextStyle(color: Bg.muted)),
              Expanded(
                child: Slider(
                  value: t.volume,
                  activeColor: Bg.lime,
                  onChanged: (v) {
                    setSheet(() => t.volume = v);
                    setState(() {});
                  },
                  onChangeEnd: (_) => _save(),
                ),
              ),
            ]),
            Row(children: [
              FilledButton.tonal(
                onPressed: () {
                  _edit(() => t.muted = !t.muted);
                  setSheet(() {});
                },
                child: Text(t.muted ? 'Slå på' : 'Tysta'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _edit(() => t.notes.clear()),
                child: const Text('Rensa noter'),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                onPressed: () {
                  Navigator.pop(context);
                  _edit(() => pattern.tracks.remove(t));
                },
                child: const Text('Ta bort spår'),
              ),
            ]),
          ]),
        );
      }),
    );
  }

  // --- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final swingPct = (50 + pattern.swing * 50).round();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          _Header(
            pattern: pattern,
            swingPct: swingPct,
            onBpm: (d) => _edit(() => pattern.bpm = (pattern.bpm + d).clamp(60, 200)),
            onSwing: (v) => _edit(() => pattern.swing = v),
            onKey: (k) => _edit(() => pattern.keyRoot = k),
            onScale: (s) => _edit(() => pattern.scale = s),
          ),
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(status, style: const TextStyle(color: Bg.muted, fontSize: 12)),
            ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: seq.currentStep,
              builder: (_, step, __) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final t in pattern.tracks) ...[
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      GestureDetector(
                        onTap: () => _trackMenu(t),
                        child: SizedBox(
                          width: 88,
                          child: Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: t.muted ? Bg.muted : Bg.text)),
                        ),
                      ),
                      Expanded(
                        child: TrackLane(
                          track: t,
                          pattern: pattern,
                          currentStep: step,
                          onTapStep: (s) => _tapStep(t, s),
                          onLongPressStep: (s) => _longPressStep(t, s),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 88),
                    child: Row(children: [
                      for (var b = 0; b < pattern.bars * 4; b++)
                        Expanded(
                            child: Text('${b % 4 + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Bg.muted, fontSize: 11))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: _addTrack,
                    icon: const Icon(Icons.add, color: Bg.lime),
                    label: const Text('Lägg till spår', style: TextStyle(color: Bg.lime)),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: Bg.lime,
        foregroundColor: Bg.base,
        onPressed: status.isNotEmpty ? null : () => setState(() => seq.toggle()),
        child: ValueListenableBuilder<int>(
          valueListenable: seq.currentStep,
          builder: (_, s, __) => Icon(seq.playing ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 40),
        ),
      ),
    );
  }

  @override
  void dispose() {
    seq.stop();
    super.dispose();
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pattern,
    required this.swingPct,
    required this.onBpm,
    required this.onSwing,
    required this.onKey,
    required this.onScale,
  });
  final Pattern pattern;
  final int swingPct;
  final void Function(double delta) onBpm;
  final void Function(double) onSwing;
  final void Function(int) onKey;
  final void Function(String) onScale;

  @override
  Widget build(BuildContext context) {
    const sep = Text('  |  ', style: TextStyle(color: Bg.muted));
    final keyName = '${noteNames[pattern.keyRoot]} ${pattern.scale}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BEATGO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          _Tap(
            label: '${pattern.bpm.round()} BPM',
            onTap: () => _bpmSheet(context),
          ),
          sep,
          _Tap(label: 'swing $swingPct%', onTap: () => _swingSheet(context)),
          sep,
          _Tap(label: keyName, onTap: () => _keySheet(context)),
          sep,
          Text('${pattern.bars} bars', style: const TextStyle(color: Bg.muted)),
        ]),
      ]),
    );
  }

  void _bpmSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Bg.lane,
        builder: (_) => StatefulBuilder(builder: (context, set) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(onPressed: () { onBpm(-1); set(() {}); }, icon: const Icon(Icons.remove)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('${pattern.bpm.round()}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700)),
              ),
              IconButton.filledTonal(onPressed: () { onBpm(1); set(() {}); }, icon: const Icon(Icons.add)),
            ]),
          );
        }),
      );

  void _swingSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Bg.lane,
        builder: (_) => StatefulBuilder(builder: (context, set) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Swing ${(50 + pattern.swing * 50).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Slider(
                value: pattern.swing,
                max: 0.5,
                activeColor: Bg.lime,
                onChanged: (v) { onSwing(v); set(() {}); },
              ),
              const Text('50 % = rakt · 58 % = typisk house · 67 % = garage', style: TextStyle(color: Bg.muted, fontSize: 12)),
            ]),
          );
        }),
      );

  void _keySheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Bg.lane,
        builder: (_) => StatefulBuilder(builder: (context, set) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, children: [
                for (var i = 0; i < 12; i++)
                  ChoiceChip(
                    label: Text(noteNames[i]),
                    selected: pattern.keyRoot == i,
                    selectedColor: Bg.lime,
                    onSelected: (_) { onKey(i); set(() {}); },
                  ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final s in scales.keys)
                  ChoiceChip(
                    label: Text(s),
                    selected: pattern.scale == s,
                    selectedColor: Bg.lime,
                    onSelected: (_) { onScale(s); set(() {}); },
                  ),
              ]),
            ]),
          );
        }),
      );
}

class _Tap extends StatelessWidget {
  const _Tap({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Text(label, style: const TextStyle(color: Bg.text, fontWeight: FontWeight.w500)),
        ),
      );
}
