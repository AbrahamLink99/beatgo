import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../main.dart';
import '../model/pattern.dart';
import 'key_screen.dart';

/// Full-screen note editor for a melodic track.
///
/// One bar at a time (16 columns). Rows are chromatic pitches, high at the
/// top; notes outside the pattern key are drawn dark and thin, and with the
/// scale lock on they refuse taps. Each row shows its scale degree.
///
/// Gestures:
///  - tap empty cell: add a note of the chosen length, select it
///  - tap a note: select it; tap the selected note again: delete it
///  - drag a note sideways: move it; drag its right edge: change length
///  - long press a note: delete
///  - toolbar: pitch ▲▼ (scale steps), velocity, delete, copy bar, clear
class PianoRoll extends StatefulWidget {
  const PianoRoll({
    super.key,
    required this.track,
    required this.pattern,
    required this.seq,
    required this.onChanged,
    required this.ensureChordTrack,
  });
  final Track track;
  final Pattern pattern;
  final Sequencer seq;
  final VoidCallback onChanged;
  final Future<Track> Function() ensureChordTrack;

  @override
  State<PianoRoll> createState() => _PianoRollState();
}

class _Row {
  final int pitch;
  final double top;
  final double height;
  final bool inKey;
  const _Row(this.pitch, this.top, this.height, this.inKey);
  double get bottom => top + height;
}

class _PianoRollState extends State<PianoRoll> {
  final engine = AudioEngine.instance;
  int bar = 0;
  int noteLen = 2; // steps
  bool hideOutside = false;
  Note? selected;

  Note? _dragNote;
  bool _dragResize = false;
  int _dragStartStep = 0;
  int _dragOrigStep = 0;
  int _dragOrigLen = 1;

  Track get t => widget.track;
  Pattern get p => widget.pattern;

  static const _rowIn = 30.0;
  static const _rowOut = 14.0;
  static const _gutter = 40.0;
  static const _degreeW = 24.0;

  /// Two octaves from the key root (octave 0 … octave 2), top → bottom.
  List<_Row> get rows {
    final root = 24 + p.keyRoot;
    final out = <_Row>[];
    var y = 0.0;
    for (var n = root + 24; n >= root; n--) {
      final ik = inKey(n, p.keyRoot, p.scale);
      if (!ik && hideOutside) continue;
      final h = ik ? _rowIn : _rowOut;
      out.add(_Row(n, y, h, ik));
      y += h + 2;
    }
    return out;
  }

  double _gridHeight(List<_Row> r) => r.isEmpty ? 0 : r.last.bottom;

  void _change() {
    widget.onChanged();
    setState(() {});
  }

  void _audition(int pitch) {
    if (widget.seq.playing) return;
    engine.trigger(t, semitones: pitch - t.rootNote, gate: const Duration(milliseconds: 220));
  }

  Note? _noteAt(int step, int pitch) {
    for (final n in t.notes) {
      if (n.pitch == pitch && step >= n.step && step < n.step + n.length) return n;
    }
    return null;
  }

  void _clearOverlap(Note keep) {
    t.notes.removeWhere((n) =>
        n != keep && n.pitch == keep.pitch && n.step < keep.step + keep.length && keep.step < n.step + n.length);
  }

  void _add(int step, int pitch) {
    final maxLen = (p.steps - step).clamp(1, noteLen);
    final n = Note(step: step, length: maxLen, pitch: pitch);
    t.notes.add(n);
    _clearOverlap(n);
    selected = n;
    _audition(pitch);
    _change();
  }

  void _replace(Note old, Note fresh) {
    final i = t.notes.indexOf(old);
    if (i < 0) return;
    t.notes[i] = fresh;
    if (selected == old) selected = fresh;
    _clearOverlap(fresh);
  }

  void _delete(Note n) {
    t.notes.remove(n);
    if (selected == n) selected = null;
    _change();
  }

  /// Move the selected note to the next in-key pitch up/down.
  void _shiftPitch(int dir) {
    final n = selected;
    if (n == null) return;
    var pitch = n.pitch;
    for (var i = 0; i < 12; i++) {
      pitch += dir;
      if (pitch < 0 || pitch > 108) return;
      if (inKey(pitch, p.keyRoot, p.scale)) break;
    }
    final fresh = n.copyWith(pitch: pitch);
    _replace(n, fresh);
    _audition(pitch);
    _change();
  }

  void _copyBar() {
    final from = bar * 16, to = ((bar + 1) % p.bars) * 16;
    if (from == to) return;
    t.notes.removeWhere((n) => n.step >= to && n.step < to + 16);
    for (final n in t.notes.where((n) => n.step >= from && n.step < from + 16).toList()) {
      t.notes.add(n.copyWith(step: n.step - from + to));
    }
    _change();
  }

  // --- gestures -------------------------------------------------------------

  (int step, _Row row)? _cellAt(Offset local, double gridW, List<_Row> r) {
    for (final row in r) {
      if (local.dy >= row.top && local.dy < row.bottom + 2) {
        final col = (local.dx / gridW * 16).floor().clamp(0, 15);
        return (bar * 16 + col, row);
      }
    }
    return null;
  }

  void _onTap(Offset local, double gridW, List<_Row> r) {
    final c = _cellAt(local, gridW, r);
    if (c == null) return;
    final (step, row) = c;
    final hit = _noteAt(step, row.pitch);
    if (hit == null) {
      if (!row.inKey && p.scaleLock) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${noteName(row.pitch)} ligger utanför ${noteNames[p.keyRoot]} ${scaleLabels[p.scale]?.toLowerCase()}. Stäng av låset under Tonart för att lägga den ändå.'),
          duration: const Duration(seconds: 2),
        ));
        return;
      }
      _add(step, row.pitch);
    } else if (selected == hit) {
      _delete(hit);
    } else {
      selected = hit;
      _audition(row.pitch);
      setState(() {});
    }
  }

  void _onLongPress(Offset local, double gridW, List<_Row> r) {
    final c = _cellAt(local, gridW, r);
    if (c == null) return;
    final hit = _noteAt(c.$1, c.$2.pitch);
    if (hit != null) _delete(hit);
  }

  void _onDragStart(Offset local, double gridW, List<_Row> r) {
    _dragNote = null;
    final c = _cellAt(local, gridW, r);
    if (c == null) return;
    final hit = _noteAt(c.$1, c.$2.pitch);
    if (hit == null) return;
    _dragNote = hit;
    selected = hit;
    _dragStartStep = c.$1;
    _dragOrigStep = hit.step;
    _dragOrigLen = hit.length;
    final colW = gridW / 16;
    final lastStep = hit.step + hit.length - 1;
    _dragResize = c.$1 == lastStep && (hit.length > 1 || (local.dx % colW) > colW * 0.6);
    setState(() {});
  }

  void _onDragUpdate(Offset local, double gridW) {
    final n = _dragNote;
    if (n == null) return;
    final col = (local.dx / gridW * 16).floor().clamp(-16, 31);
    final delta = bar * 16 + col - _dragStartStep;
    Note fresh;
    if (_dragResize) {
      final len = (_dragOrigLen + delta).clamp(1, p.steps - n.step);
      if (len == n.length) return;
      fresh = n.copyWith(length: len);
    } else {
      final s = (_dragOrigStep + delta).clamp(0, p.steps - n.length);
      if (s == n.step) return;
      fresh = n.copyWith(step: s);
    }
    _replace(n, fresh);
    _dragNote = fresh;
    setState(() {});
  }

  void _onDragEnd() {
    if (_dragNote != null) widget.onChanged();
    _dragNote = null;
  }

  void _openKey() {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => KeyScreen(pattern: p, onChanged: widget.onChanged, ensureChordTrack: widget.ensureChordTrack),
        ))
        .then((_) => setState(() {}));
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final r = rows;
    final sel = selected;
    final keyNotes = [for (final d in scales[p.scale]!) noteNames[(p.keyRoot + d) % 12]];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Bg.base,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.name),
          Text('sample ${noteName(t.rootNote)}', style: const TextStyle(fontSize: 11, color: Bg.muted)),
        ]),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: widget.seq.currentStep,
            builder: (_, s, __) => IconButton(
              onPressed: () => setState(() => widget.seq.toggle()),
              icon: Icon(widget.seq.playing ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Bg.lime, size: 30),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // bar + length + hide-outside
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(children: [
            SegmentedButton<int>(
              segments: [for (var b = 0; b < p.bars; b++) ButtonSegment(value: b, label: Text('Takt ${b + 1}'))],
              selected: {bar},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (s) => setState(() => bar = s.first),
            ),
            const Spacer(),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1/16')),
                ButtonSegment(value: 2, label: Text('1/8')),
                ButtonSegment(value: 4, label: Text('1/4')),
              ],
              selected: {noteLen},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (s) => setState(() => noteLen = s.first),
            ),
          ]),
        ),
        // key strip
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Material(
              color: Bg.lime,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _openKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${noteNames[p.keyRoot]} ${scaleLabels[p.scale]?.toLowerCase() ?? p.scale}',
                        style: const TextStyle(color: Bg.base, fontWeight: FontWeight.w800, fontSize: 12)),
                    const Icon(Icons.expand_more, size: 16, color: Bg.base),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(spacing: 4, children: [
                for (final n in keyNotes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Bg.lane, borderRadius: BorderRadius.circular(6)),
                    child: Text(n, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
            TextButton(
              onPressed: () => setState(() => hideOutside = !hideOutside),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: Text(hideOutside ? 'visa alla' : 'dölj utanför', style: const TextStyle(color: Bg.muted, fontSize: 11)),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            child: ValueListenableBuilder<int>(
              valueListenable: widget.seq.currentStep,
              builder: (_, step, __) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: _gutter,
                  height: _gridHeight(r),
                  child: CustomPaint(painter: _GutterPainter(r, p.keyRoot)),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final w = c.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _onTap(d.localPosition, w, r),
                      onLongPressStart: (d) => _onLongPress(d.localPosition, w, r),
                      onHorizontalDragStart: (d) => _onDragStart(d.localPosition, w, r),
                      onHorizontalDragUpdate: (d) => _onDragUpdate(d.localPosition, w),
                      onHorizontalDragEnd: (_) => _onDragEnd(),
                      onHorizontalDragCancel: _onDragEnd,
                      child: CustomPaint(
                        size: Size(w, _gridHeight(r)),
                        painter: _GridPainter(rows: r, notes: t.notes, bar: bar, selected: sel, playStep: step, keyRoot: p.keyRoot),
                      ),
                    );
                  }),
                ),
                SizedBox(
                  width: _degreeW,
                  height: _gridHeight(r),
                  child: CustomPaint(painter: _DegreePainter(r, p.keyRoot)),
                ),
              ]),
            ),
          ),
        ),
        // toolbar
        Container(
          color: Bg.lane,
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (sel == null)
              const SizedBox(
                height: 40,
                child: Center(
                  child: Text('Tryck i gridet för en ton · dra för att flytta · dra högerkanten för längd',
                      style: TextStyle(color: Bg.muted, fontSize: 11), textAlign: TextAlign.center),
                ),
              )
            else
              Row(children: [
                SizedBox(
                  width: 44,
                  child: Text('${noteName(sel.pitch)}\n${degreeOf(sel.pitch, p.keyRoot)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Bg.lime, height: 1.1)),
                ),
                IconButton(onPressed: () => _shiftPitch(1), icon: const Icon(Icons.keyboard_arrow_up)),
                IconButton(onPressed: () => _shiftPitch(-1), icon: const Icon(Icons.keyboard_arrow_down)),
                const Text('vel', style: TextStyle(color: Bg.muted, fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: sel.velocity.toDouble(),
                    min: 1,
                    max: 127,
                    activeColor: Bg.lime,
                    onChanged: (v) {
                      _replace(sel, sel.copyWith(velocity: v.round()));
                      setState(() {});
                    },
                    onChangeEnd: (_) => widget.onChanged(),
                  ),
                ),
                IconButton(onPressed: () => _delete(sel), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
              ]),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: p.bars > 1 ? _copyBar : null,
                  child: Text('Kopiera takt ${bar + 1} → ${(bar + 1) % p.bars + 1}', style: const TextStyle(fontSize: 12)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    t.notes.removeWhere((n) => n.step >= bar * 16 && n.step < bar * 16 + 16);
                    selected = null;
                    _change();
                  },
                  child: const Text('Rensa takten', style: TextStyle(fontSize: 12)),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _GutterPainter extends CustomPainter {
  _GutterPainter(this.rows, this.keyRoot);
  final List<_Row> rows;
  final int keyRoot;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in rows) {
      final isRoot = r.pitch % 12 == keyRoot;
      final tp = TextPainter(
        text: TextSpan(
          text: noteName(r.pitch),
          style: TextStyle(
            color: isRoot ? Bg.lime : (r.inKey ? Bg.text : Bg.muted.withValues(alpha: 0.6)),
            fontSize: r.inKey ? 11 : 9,
            fontWeight: isRoot ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 6, r.top + (r.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_GutterPainter old) => true;
}

class _DegreePainter extends CustomPainter {
  _DegreePainter(this.rows, this.keyRoot);
  final List<_Row> rows;
  final int keyRoot;

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in rows) {
      if (!r.inKey) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: degreeOf(r.pitch, keyRoot),
          style: TextStyle(color: r.pitch % 12 == keyRoot ? Bg.lime : Bg.muted, fontSize: 9, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, r.top + (r.height - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_DegreePainter old) => true;
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.rows,
    required this.notes,
    required this.bar,
    required this.selected,
    required this.playStep,
    required this.keyRoot,
  });
  final List<_Row> rows;
  final List<Note> notes;
  final int bar;
  final Note? selected;
  final int playStep;
  final int keyRoot;

  @override
  void paint(Canvas canvas, Size size) {
    final colW = size.width / 16;
    final first = bar * 16;
    final rowOf = {for (final r in rows) r.pitch: r};

    for (final r in rows) {
      final isRoot = r.pitch % 12 == keyRoot;
      final paint = Paint()
        ..color = !r.inKey
            ? Bg.base
            : isRoot
                ? Bg.laneAlt
                : Bg.lane;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, r.top, size.width, r.height), const Radius.circular(6)),
        paint,
      );
      if (!r.inKey) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(0, r.top, size.width, r.height), const Radius.circular(6)),
          Paint()
            ..color = Bg.line.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke,
        );
      }
    }

    final beat = Paint()..color = Bg.line..strokeWidth = 1;
    final strong = Paint()..color = Bg.muted.withValues(alpha: 0.5)..strokeWidth = 1;
    for (var c = 1; c < 16; c++) {
      final x = c * colW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), c % 4 == 0 ? strong : beat);
    }

    for (final n in notes) {
      final r = rowOf[n.pitch];
      if (r == null) continue;
      final s0 = n.step - first;
      final s1 = s0 + n.length;
      if (s1 <= 0 || s0 >= 16) continue;
      final x0 = s0.clamp(0, 16) * colW + 2;
      final x1 = s1.clamp(0, 16) * colW - 2;
      final pad = r.inKey ? 4.0 : 2.0;
      final rect = RRect.fromRectAndRadius(Rect.fromLTRB(x0, r.top + pad, x1, r.bottom - pad), const Radius.circular(5));
      canvas.drawRRect(rect, Paint()..color = (r.inKey ? Bg.lime : const Color(0xFFE0A84A)).withValues(alpha: 0.5 + 0.5 * n.velocity / 127));
      if (identical(n, selected)) {
        canvas.drawRRect(rect, Paint()
          ..color = Bg.text
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
      if (n.length > 1 && s1 <= 16 && r.inKey) {
        canvas.drawLine(Offset(x1 - 5, r.top + 9), Offset(x1 - 5, r.bottom - 9),
            Paint()..color = Bg.base.withValues(alpha: 0.6)..strokeWidth = 2);
      }
    }

    final ps = playStep - first;
    if (ps >= 0 && ps < 16) {
      final x = ps * colW + colW / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = Bg.playhead..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
