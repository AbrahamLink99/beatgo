import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../main.dart';
import '../model/pattern.dart';

/// Key picker: root + scale, a keyboard showing the playable notes,
/// diatonic chord buttons that drop a chord into the Chords channel,
/// and the scale lock. Applies to every piano roll in the pattern.
class KeyScreen extends StatefulWidget {
  const KeyScreen({super.key, required this.pattern, required this.onChanged, required this.ensureChordTrack});
  final Pattern pattern;
  final VoidCallback onChanged;

  /// Returns the Chords track, creating it (with a sample loaded) if needed.
  final Future<Track> Function() ensureChordTrack;

  @override
  State<KeyScreen> createState() => _KeyScreenState();
}

class _KeyScreenState extends State<KeyScreen> {
  Pattern get p => widget.pattern;
  final engine = AudioEngine.instance;
  int chordBar = 0;

  void _change() {
    widget.onChanged();
    setState(() {});
  }

  Future<void> _addChord(ChordSuggestion c) async {
    final t = await widget.ensureChordTrack();
    final start = chordBar * 16;
    t.notes.removeWhere((n) => n.step >= start && n.step < start + 16);
    for (final pitch in c.pitches(p.keyRoot)) {
      t.notes.add(Note(step: start, length: 15, pitch: pitch, velocity: 90));
      engine.trigger(t, semitones: pitch - t.rootNote, velocity: 0.7, gate: const Duration(milliseconds: 600));
    }
    chordBar = (chordBar + 1) % p.bars;
    _change();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${c.name} lagt i Chords, takt ${(start ~/ 16) + 1}'),
        duration: const Duration(milliseconds: 900),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final chords = chordsFor(p.keyRoot, p.scale);
    final inScale = [for (var i = 0; i < 12; i++) inKey(i, p.keyRoot, p.scale)];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Bg.base,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tonart'),
          Text('gäller alla kanaler i loopen', style: TextStyle(fontSize: 11, color: Bg.muted)),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _Label('GRUNDTON'),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.3,
            children: [
              for (var i = 0; i < 12; i++)
                _Pill(
                  label: noteNames[i],
                  on: p.keyRoot == i,
                  onTap: () {
                    p.keyRoot = i;
                    _change();
                  },
                ),
            ],
          ),
          const SizedBox(height: 18),
          const _Label('SKALA'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final s in scales.keys) ...[
                _Pill(
                  label: scaleLabels[s] ?? s,
                  on: p.scale == s,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  onTap: () {
                    p.scale = s;
                    _change();
                  },
                ),
                const SizedBox(width: 6),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          const _Label('DE HÄR TONERNA KAN DU SPELA'),
          SizedBox(height: 120, child: _Keyboard(inScale: inScale, keyRoot: p.keyRoot)),
          const SizedBox(height: 6),
          Text(
            [for (final d in scales[p.scale]!) noteNames[(p.keyRoot + d) % 12]].join(' · '),
            style: const TextStyle(color: Bg.lime, fontWeight: FontWeight.w700),
          ),
          const Text('Grönt = i tonarten. Siffran är steget i skalan: samma siffror i varje tonart.',
              style: TextStyle(color: Bg.muted, fontSize: 11, height: 1.5)),
          const SizedBox(height: 18),
          Row(children: [
            const _Label('ACKORD SOM PASSAR'),
            const Spacer(),
            Text('→ Chords, takt ${chordBar + 1}', style: const TextStyle(color: Bg.muted, fontSize: 11)),
          ]),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in chords)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 32 - 6 * 3) / 4,
                child: Material(
                  color: Bg.lane,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _addChord(c),
                    child: SizedBox(
                      height: 60,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text(c.numeral, style: const TextStyle(fontSize: 10, color: Bg.muted, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          const Text('Tryck = ackordet läggs över en hel takt i Chords. Nästa tryck tar nästa takt.',
              style: TextStyle(color: Bg.muted, fontSize: 11, height: 1.5)),
          const SizedBox(height: 18),
          const _Label('LÅS'),
          SwitchListTile(
            value: p.scaleLock,
            activeColor: Bg.lime,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            tileColor: Bg.lane,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: const Text('Bara toner i tonarten i piano roll', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            onChanged: (v) {
              p.scaleLock = v;
              _change();
            },
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Av: toner utanför visas smala och mörka men går att lägga ändå (blue notes, kromatiska gångar).',
                style: TextStyle(color: Bg.muted, fontSize: 11, height: 1.5)),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Bg.lime, foregroundColor: Bg.base, minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.pop(context),
            child: Text('Klar – ${noteNames[p.keyRoot]} ${scaleLabels[p.scale]?.toLowerCase() ?? p.scale}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 10, letterSpacing: 1.4, color: Bg.muted, fontWeight: FontWeight.w700)),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap, this.padding});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final EdgeInsets? padding;
  @override
  Widget build(BuildContext context) => Material(
        color: on ? Bg.lime : Bg.lane,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            padding: padding,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Bg.base : Bg.text)),
          ),
        ),
      );
}

/// One octave, C to B. White keys lit lime when in key; black keys dim lime.
class _Keyboard extends StatelessWidget {
  const _Keyboard({required this.inScale, required this.keyRoot});
  final List<bool> inScale;
  final int keyRoot;

  static const _whites = [0, 2, 4, 5, 7, 9, 11];
  static const _blacks = {1: 0, 3: 1, 6: 3, 8: 4, 10: 5}; // pitch class → white index it sits after

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final ww = (c.maxWidth - 6 * 2) / 7;
        return Stack(children: [
          Row(children: [
            for (var i = 0; i < 7; i++) ...[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: inScale[_whites[i]] ? Bg.lime : Bg.text,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    inScale[_whites[i]] ? '${noteNames[_whites[i]]} · ${degreeOf(_whites[i], keyRoot)}' : noteNames[_whites[i]],
                    style: const TextStyle(color: Bg.base, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (i < 6) const SizedBox(width: 2),
            ],
          ]),
          for (final e in _blacks.entries)
            Positioned(
              left: (e.value + 1) * (ww + 2) - ww * 0.3,
              top: 0,
              width: ww * 0.6,
              height: 70,
              child: Container(
                decoration: BoxDecoration(
                  color: inScale[e.key] ? Bg.limeDim : Bg.laneAlt,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                ),
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  inScale[e.key] ? '${noteNames[e.key]}\n${degreeOf(e.key, keyRoot)}' : noteNames[e.key],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: inScale[e.key] ? Bg.base : Bg.muted, fontSize: 8, fontWeight: FontWeight.w800, height: 1.1),
                ),
              ),
            ),
        ]);
      });
}
