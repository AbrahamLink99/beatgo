import 'package:beatgo/model/pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pattern survives a json round-trip', () {
    final p = Pattern.demo();
    final back = Pattern.fromJson(p.toJson());
    expect(back.steps, p.steps);
    expect(back.tracks.length, p.tracks.length);
    expect(back.tracks.last.notes.length, p.tracks.last.notes.length);
    expect(back.tracks.last.notes.first.pitch, 42);
  });

  test('note names follow Ableton convention', () {
    expect(noteName(36), 'C1');
    expect(noteName(42), 'F#1');
    expect(noteName(60), 'C3');
  });

  test('noteAt covers the full length of a note', () {
    final t = Track(name: 'b', kind: TrackKind.melodic, samplePath: 'x', rootNote: 24,
        notes: const [Note(step: 4, length: 3, pitch: 40)]);
    expect(t.noteAt(3), isNull);
    expect(t.noteAt(4), isNotNull);
    expect(t.noteAt(6), isNotNull);
    expect(t.noteAt(7), isNull);
  });
}
