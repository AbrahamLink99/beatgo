/// Data model for a BeatGo loop ("pattern").
///
/// Everything is in 16th-note steps. A pattern is `bars * 16` steps long.
/// A track is one row in the sequencer: a name, a sample, and its notes.
/// Drum tracks have a single fixed pitch; melodic tracks pitch the sample.
library;

enum TrackKind { drum, melodic }

class Note {
  /// Start step, 0-based, within the pattern.
  final int step;

  /// Length in steps (>= 1). Drum hits are 1.
  final int length;

  /// MIDI note number. For drum tracks this is the track's fixed note.
  final int pitch;

  /// 1..127
  final int velocity;

  const Note({
    required this.step,
    this.length = 1,
    required this.pitch,
    this.velocity = 100,
  });

  Note copyWith({int? step, int? length, int? pitch, int? velocity}) => Note(
        step: step ?? this.step,
        length: length ?? this.length,
        pitch: pitch ?? this.pitch,
        velocity: velocity ?? this.velocity,
      );

  Map<String, dynamic> toJson() =>
      {'step': step, 'length': length, 'pitch': pitch, 'velocity': velocity};

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        step: j['step'] as int,
        length: (j['length'] as int?) ?? 1,
        pitch: j['pitch'] as int,
        velocity: (j['velocity'] as int?) ?? 100,
      );
}

class Track {
  String name;
  TrackKind kind;

  /// Asset path (`assets/samples/kick.wav`) or absolute file path on device.
  String samplePath;

  /// For drum tracks: the MIDI note this row sends (Drum Rack pad).
  /// For melodic tracks: the pitch the sample was recorded at.
  int rootNote;

  /// 0..1
  double volume;
  bool muted;
  List<Note> notes;

  Track({
    required this.name,
    required this.kind,
    required this.samplePath,
    required this.rootNote,
    this.volume = 0.85,
    this.muted = false,
    List<Note>? notes,
  }) : notes = notes ?? [];

  bool get isDrum => kind == TrackKind.drum;

  Note? noteAt(int step) {
    for (final n in notes) {
      if (step >= n.step && step < n.step + n.length) return n;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'samplePath': samplePath,
        'rootNote': rootNote,
        'volume': volume,
        'muted': muted,
        'notes': notes.map((n) => n.toJson()).toList(),
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        name: j['name'] as String,
        kind: TrackKind.values.byName(j['kind'] as String),
        samplePath: j['samplePath'] as String,
        rootNote: j['rootNote'] as int,
        volume: (j['volume'] as num?)?.toDouble() ?? 0.85,
        muted: (j['muted'] as bool?) ?? false,
        notes: ((j['notes'] as List?) ?? [])
            .map((e) => Note.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Pattern {
  String name;
  double bpm;

  /// 0..1 — how far odd 16ths are pushed toward the next step.
  /// Shown as 50–75 % "MPC style" in the UI (0 = 50 %, 0.5 = 75 %).
  double swing;

  /// 0 = C … 11 = B
  int keyRoot;
  String scale; // minor | major | dorian
  int bars;
  List<Track> tracks;

  Pattern({
    this.name = 'Untitled',
    this.bpm = 124,
    this.swing = 0.16,
    this.keyRoot = 6,
    this.scale = 'minor',
    this.bars = 2,
    List<Track>? tracks,
  }) : tracks = tracks ?? [];

  int get steps => bars * 16;

  Map<String, dynamic> toJson() => {
        'name': name,
        'bpm': bpm,
        'swing': swing,
        'keyRoot': keyRoot,
        'scale': scale,
        'bars': bars,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Pattern.fromJson(Map<String, dynamic> j) => Pattern(
        name: (j['name'] as String?) ?? 'Untitled',
        bpm: (j['bpm'] as num).toDouble(),
        swing: (j['swing'] as num?)?.toDouble() ?? 0,
        keyRoot: (j['keyRoot'] as int?) ?? 0,
        scale: (j['scale'] as String?) ?? 'minor',
        bars: (j['bars'] as int?) ?? 2,
        tracks: ((j['tracks'] as List?) ?? [])
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// A demo groove so the app plays something the first time it opens.
  factory Pattern.demo() {
    const kick = 36, clap = 38, ch = 42, oh = 46, shk = 37;
    List<Note> hits(int pitch, List<int> steps, {int vel = 100}) =>
        [for (final s in steps) Note(step: s, pitch: pitch, velocity: vel)];
    const fs1 = 42; // F#1
    return Pattern(
      name: 'Demo',
      bpm: 124,
      swing: 0.16,
      keyRoot: 6,
      scale: 'minor',
      bars: 2,
      tracks: [
        Track(
            name: 'Kick',
            kind: TrackKind.drum,
            samplePath: 'assets/samples/kick.wav',
            rootNote: kick,
            notes: hits(kick, [0, 4, 8, 12, 16, 20, 24, 28], vel: 120)),
        Track(
            name: 'Clap',
            kind: TrackKind.drum,
            samplePath: 'assets/samples/clap.wav',
            rootNote: clap,
            notes: hits(clap, [4, 12, 20, 28])),
        Track(
            name: 'Open hat',
            kind: TrackKind.drum,
            samplePath: 'assets/samples/hat_open.wav',
            rootNote: oh,
            notes: hits(oh, [2, 6, 10, 14, 18, 22, 26, 30], vel: 90)),
        Track(
            name: 'Closed hat',
            kind: TrackKind.drum,
            samplePath: 'assets/samples/hat_closed.wav',
            rootNote: ch,
            notes: hits(ch, [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31], vel: 70)),
        Track(
            name: 'Shaker',
            kind: TrackKind.drum,
            samplePath: 'assets/samples/shaker.wav',
            rootNote: shk,
            volume: 0.6,
            notes: [
              for (var s = 0; s < 32; s++)
                Note(step: s, pitch: shk, velocity: s % 2 == 0 ? 85 : 55)
            ]),
        Track(
            name: 'Bass',
            kind: TrackKind.melodic,
            samplePath: 'assets/samples/bass_c1.wav',
            rootNote: 24, // sample recorded at C1
            notes: const [
              Note(step: 2, length: 2, pitch: fs1),
              Note(step: 6, length: 1, pitch: fs1),
              Note(step: 10, length: 2, pitch: fs1 + 12, velocity: 90),
              Note(step: 14, length: 1, pitch: fs1),
              Note(step: 18, length: 2, pitch: fs1),
              Note(step: 22, length: 1, pitch: fs1 + 3),
              Note(step: 26, length: 2, pitch: fs1 + 10, velocity: 90),
              Note(step: 29, length: 3, pitch: fs1),
            ]),
      ],
    );
  }
}

const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Ableton-style name: C1 = MIDI 36 → (36 ~/ 12) - 2 = 1.
String noteName(int midi) => '${noteNames[midi % 12]}${midi ~/ 12 - 2}';

const scales = <String, List<int>>{
  'minor': [0, 2, 3, 5, 7, 8, 10],
  'major': [0, 2, 4, 5, 7, 9, 11],
  'dorian': [0, 2, 3, 5, 7, 9, 10],
};
