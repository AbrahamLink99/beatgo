import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../main.dart';
import '../model/pattern.dart';

/// Full-screen note editor for a melodic track.
///
/// One bar at a time (16 columns), so cells are finger-sized on a phone.
/// Rows are pitches, high at the top; by default only scale notes are shown.
///
/// Gestures:
///  - tap empty cell: add a note of the chosen length, select it
///  - tap a note: select it; tap the selected note again: delete it
///  - drag a note sideways: move it; drag its right edge: change length
///  - long press a note: delete
///  - toolbar: pitch ▲▼ (scale steps), velocity, length, delete
class PianoRoll extends StatefulWidget {
  const PianoRoll({
    super.key,
    required this.track,
    required this.pattern,
    required this.seq,
    required this.onChanged,
  });
  final Track track;
  final Pattern pattern;
  final Sequencer seq;
  final VoidCallback onChanged;

  @override
  State<PianoRoll> createState() => _PianoRollState();
}

class _PianoRollState extends State<PianoRoll> {
  final engine = AudioEngine.instance;
  int bar = 0;
  int noteLen = 2; // steps
  bool scaleOnly = true;
  Note? selected;

  // drag state
  Note? _dragNote;
  bool _dragResize = false;
  int _dragStartStep = 0;
  int _dragOrigStep = 0;
  int _dragOrigLen = 1;

  Track get t => widget.track;
  Pattern get p => widget.pattern;

  /// Pitches shown, top → bottom. Two octaves from the key root (octave 0).
  List<int> get rows {
    final root = 24 + p.keyRoot; // key root in Ableton octave 0
    final degrees = scales[p.scale]!;
    final out = <int>[];
    for (var n = root + 24; n >= root; n--) {
      if (scaleOnly && !degrees.contains((n - root) % 12)) continue;
      out.add(n);
    }
    return out;
  }

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

  void _shiftPitch(int dir) {
    final n = selected;
    if (n == null) return;
    final r = rows; // top → bottom
    final i = r.indexOf(n.pitch);
    final j = i < 0 ? -1 : i - dir; // up = towards index 0
    if (j < 0 || j >= r.length) return;
    final fresh = n.copyWith(pitch: r[j]);
    _replace(n, fresh);
    _audition(fresh.pitch);
    _change();
  }

  // --- gestures -------------------------------------------------------------

  static const _rowH = 30.0;
  static const _gutter = 42.0;

  (int step, int pitch)? _cellAt(Offset local, double gridW) {
    final r = rows;
    final row = (local.dy / _rowH).floor();
    if (row < 0 || row >= r.length) return null;
    final col = ((local.dx) / gridW * 16).floor().clamp(0, 15);
    return (bar * 16 + col, r[row]);
  }

  void _onTap(Offset local, double gridW) {
    final c = _cellAt(local, gridW);
    if (c == null) return;
    final (step, pitch) = c;
    final hit = _noteAt(step, pitch);
    if (hit == null) {
      _add(step, pitch);
    } else if (selected == hit) {
      _delete(hit);
    } else {
      selected = hit;
      _audition(pitch);
      setState(() {});
    }
  }

  void _onLongPress(Offset local, double gridW) {
    final c = _cellAt(local, gridW);
    if (c == null) return;
    final hit = _noteAt(c.$1, c.$2);
    if (hit != null) _delete(hit);
  }

  void _onDragStart(Offset local, double gridW) {
    final c = _cellAt(local, gridW);
    _dragNote = null;
    if (c == null) return;
    final hit = _noteAt(c.$1, c.$2);
    if (hit == null) return;
    _dragNote = hit;
    selected = hit;
    _dragStartStep = c.$1;
    _dragOrigStep = hit.step;
    _dragOrigLen = hit.length;
    // right-most step of the note = resize handle
    _dragResize = c.$1 == hit.step + hit.length - 1 && hit.length > 1 || (hit.length == 1 && (local.dx % (gridW / 16)) > gridW / 16 * 0.6);
    setState(() {});
  }

  void _onDragUpdate(Offset local, double gridW) {
    final n = _dragNote;
    if (n == null) return;
    final col = ((local.dx) / gridW * 16).floor().clamp(-16, 31);
    final step = bar * 16 + col;
    final delta = step - _dragStartStep;
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

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final r = rows;
    final sel = selected;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Bg.base,
        title: Text(t.name),
        actions: [
          TextButton(
            onPressed: () => setState(() => scaleOnly = !scaleOnly),
            child: Text(scaleOnly ? 'skala' : 'kromatisk', style: const TextStyle(color: Bg.muted)),
          ),
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
        // bar switcher + note length
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            SegmentedButton<int>(
              segments: [for (var b = 0; b < p.bars; b++) ButtonSegment(value: b, label: Text('Takt ${b + 1}'))],
              selected: {bar},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => bar = s.first),
            ),
            const Spacer(),
            const Text('längd', style: TextStyle(color: Bg.muted, fontSize: 12)),
            const SizedBox(width: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1/16')),
                ButtonSegment(value: 2, label: Text('1/8')),
                ButtonSegment(value: 4, label: Text('1/4')),
              ],
              selected: {noteLen},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => noteLen = s.first),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 16, 24),
            child: ValueListenableBuilder<int>(
              valueListenable: widget.seq.currentStep,
              builder: (_, step, __) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: _gutter,
                  height: r.length * _rowH,
                  child: CustomPaint(painter: _GutterPainter(r, p.keyRoot)),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, c) {
                    final w = c.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _onTap(d.localPosition, w),
                      onLongPressStart: (d) => _onLongPress(d.localPosition, w),
                      onHorizontalDragStart: (d) => _onDragStart(d.localPosition, w),
                      onHorizontalDragUpdate: (d) => _onDragUpdate(d.localPosition, w),
                      onHorizontalDragEnd: (_) => _onDragEnd(),
                      onHorizontalDragCancel: _onDragEnd,
                      child: CustomPaint(
                        size: Size(w, r.length * _rowH),
                        painter: _GridPainter(
                          rows: r,
                          notes: t.notes,
                          bar: bar,
                          selected: sel,
                          playStep: step,
                          keyRoot: p.keyRoot,
                          scale: p.scale,
                        ),
                      ),
                    );
                  }),
                ),
              ]),
            ),
          ),
        ),
        // selection toolbar
        Container(
          color: Bg.lane,
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
          child: sel == null
              ? const SizedBox(
                  height: 44,
                  child: Center(
                    child: Text('Tryck i rutnätet för att lägga en ton · dra för att flytta · dra högerkanten för längd',
                        style: TextStyle(color: Bg.muted, fontSize: 11), textAlign: TextAlign.center),
                  ),
                )
              : Row(children: [
                  Text(noteName(sel.pitch), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Bg.lime)),
                  IconButton(onPressed: () => _shiftPitch(1), icon: const Icon(Icons.keyboard_arrow_up)),
                  IconButton(onPressed: () => _shiftPitch(-1), icon: const Icon(Icons.keyboard_arrow_down)),
                  const SizedBox(width: 4),
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
                  IconButton(
                    onPressed: () => _delete(sel),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                ]),
        ),
      ]),
    );
  }
}

class _GutterPainter extends CustomPainter {
  _GutterPainter(this.rows, this.keyRoot);
  final List<int> rows;
  final int keyRoot;

  @override
  void paint(Canvas canvas, Size size) {
    const rowH = _PianoRollState._rowH;
    for (var i = 0; i < rows.length; i++) {
      final n = rows[i];
      final isRoot = n % 12 == keyRoot;
      final tp = TextPainter(
        text: TextSpan(
          text: noteName(n),
          style: TextStyle(
            color: isRoot ? Bg.lime : Bg.muted,
            fontSize: 11,
            fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 6, i * rowH + (rowH - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_GutterPainter old) => old.rows != rows || old.keyRoot != keyRoot;
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.rows,
    required this.notes,
    required this.bar,
    required this.selected,
    required this.playStep,
    required this.keyRoot,
    required this.scale,
  });
  final List<int> rows;
  final List<Note> notes;
  final int bar;
  final Note? selected;
  final int playStep;
  final int keyRoot;
  final String scale;

  @override
  void paint(Canvas canvas, Size size) {
    const rowH = _PianoRollState._rowH;
    final colW = size.width / 16;
    final degrees = scales[scale]!;
    final first = bar * 16;

    // row backgrounds
    for (var i = 0; i < rows.length; i++) {
      final n = rows[i];
      final rel = (n - keyRoot) % 12;
      final inScale = degrees.contains(rel);
      final isRoot = rel == 0;
      final paint = Paint()
        ..color = isRoot
            ? Bg.laneAlt
            : inScale
                ? Bg.lane
                : Bg.base;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, i * rowH + 1, size.width, rowH - 2),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
    }

    // beat lines
    final beat = Paint()..color = Bg.line..strokeWidth = 1;
    final strong = Paint()..color = Bg.muted.withValues(alpha: 0.5)..strokeWidth = 1;
    for (var c = 1; c < 16; c++) {
      final x = c * colW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), c % 4 == 0 ? strong : beat);
    }

    // notes in this bar
    for (final n in notes) {
      final row = rows.indexOf(n.pitch);
      if (row < 0) continue;
      final s0 = n.step - first;
      final s1 = s0 + n.length;
      if (s1 <= 0 || s0 >= 16) continue;
      final x0 = s0.clamp(0, 16) * colW + 2;
      final x1 = s1.clamp(0, 16) * colW - 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x0, row * rowH + 4, x1, (row + 1) * rowH - 4),
        const Radius.circular(5),
      );
      final isSel = identical(n, selected);
      canvas.drawRRect(
        rect,
        Paint()..color = Bg.lime.withValues(alpha: 0.5 + 0.5 * n.velocity / 127),
      );
      if (isSel) {
        canvas.drawRRect(rect, Paint()
          ..color = Bg.text
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
      // resize handle hint
      if (n.length > 1 && s1 <= 16) {
        canvas.drawLine(Offset(x1 - 5, row * rowH + 9), Offset(x1 - 5, (row + 1) * rowH - 9),
            Paint()..color = Bg.base.withValues(alpha: 0.6)..strokeWidth = 2);
      }
    }

    // playhead
    final ps = playStep - first;
    if (ps >= 0 && ps < 16) {
      final x = ps * colW + colW / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = Bg.playhead..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
