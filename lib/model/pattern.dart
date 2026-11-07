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
  String scale; // key of [scales]
  int bars;

  /// When true the piano roll refuses notes outside the key.
  bool scaleLock;
  List<Track> tracks;

  Pattern({
    this.name = 'Untitled',
    this.bpm = 124,
    this.swing = 0.16,
    this.keyRoot = 6,
    this.scale = 'minor',
    this.bars = 2,
    this.scaleLock = true,
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
        'scaleLock': scaleLock,
        'tracks': tracks.map((t) => t.toJson()).toList(),
      };

  factory Pattern.fromJson(Map<String, dynamic> j) => Pattern(
        name: (j['name'] as String?) ?? 'Untitled',
        bpm: (j['bpm'] as num).toDouble(),
        swing: (j['swing'] as num?)?.toDouble() ?? 0,
        keyRoot: (j['keyRoot'] as int?) ?? 0,
        scale: scales.containsKey(j['scale']) ? j['scale'] as String : 'minor',
        bars: (j['bars'] as int?) ?? 2,
        scaleLock: (j['scaleLock'] as bool?) ?? true,
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
  'harmonic minor': [0, 2, 3, 5, 7, 8, 11],
  'pentatonic': [0, 3, 5, 7, 10],
};

const scaleLabels = <String, String>{
  'minor': 'Moll',
  'major': 'Dur',
  'dorian': 'Dorisk',
  'harmonic minor': 'Harm. moll',
  'pentatonic': 'Pentatonisk',
};

/// Scale-degree label for a semitone interval above the key root.
/// Same numbers in every key, so a bassline reads the same in F#m and Am.
const degreeLabels = ['1', 'b2', '2', 'b3', '3', '4', 'b5', '5', 'b6', '6', 'b7', '7'];

String degreeOf(int pitch, int keyRoot) => degreeLabels[(pitch - keyRoot) % 12];

bool inKey(int pitch, int keyRoot, String scale) =>
    scales[scale]!.contains((pitch - keyRoot) % 12);

/// A diatonic chord suggestion built on a scale degree.
class ChordSuggestion {
  final String name; // "F#m", "D", "C#dim"
  final String numeral; // "i", "VI", "vii°"
  final List<int> intervals; // semitones above the key root

  const ChordSuggestion(this.name, this.numeral, this.intervals);

  /// MIDI pitches with the chord root placed in [octave] (Ableton naming, C3 = 60).
  List<int> pitches(int keyRoot, {int octave = 3}) {
    final base = (octave + 2) * 12 + keyRoot;
    return intervals.map((i) => base + i).toList();
  }
}

/// Triads on every degree of a 7-note scale (pentatonic: on its 5 notes).
List<ChordSuggestion> chordsFor(int keyRoot, String scale) {
  final deg = scales[scale]!;
  const roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];
  final out = <ChordSuggestion>[];
  for (var i = 0; i < deg.length; i++) {
    final r = deg[i];
    final third = deg[(i + 2) % deg.length] + ((i + 2) >= deg.length ? 12 : 0);
    final fifth = deg[(i + 4) % deg.length] + ((i + 4) >= deg.length ? 12 : 0);
    final t = third - r, f = fifth - r;
    String quality, num;
    if (t == 4 && f == 7) {
      quality = '';
      num = roman[i % 7];
    } else if (t == 3 && f == 7) {
      quality = 'm';
      num = roman[i % 7].toLowerCase();
    } else if (t == 3 && f == 6) {
      quality = 'dim';
      num = '${roman[i % 7].toLowerCase()}°';
    } else if (t == 4 && f == 8) {
      quality = 'aug';
      num = '${roman[i % 7]}+';
    } else {
      quality = 'sus';
      num = roman[i % 7];
    }
    out.add(ChordSuggestion(noteNames[(keyRoot + r) % 12] + quality, num, [r, r + t, r + f]));
  }
  return out;
}
