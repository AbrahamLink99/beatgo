import 'package:flutter/material.dart';

import '../main.dart';
import '../model/pattern.dart';

/// One sequencer row on the overview: rounded lane, beat lines, lime pills,
/// playhead. Shows steps [firstStep, firstStep + stepCount).
///
/// Drum lanes: tap toggles a hit, horizontal drag paints (on or off,
/// decided by the first cell), long press cycles accent.
/// Melodic lanes: pills sit at their pitch height; tapping opens the editor.
class TrackLane extends StatefulWidget {
  const TrackLane({
    super.key,
    required this.track,
    required this.pattern,
    required this.currentStep,
    required this.firstStep,
    required this.stepCount,
    required this.onTapStep,
    required this.onLongPressStep,
    this.onPaintStep,
    this.height = 38,
  });

  final Track track;
  final Pattern pattern;
  final int currentStep;
  final int firstStep;
  final int stepCount;
  final void Function(int step) onTapStep;
  final void Function(int step) onLongPressStep;

  /// Called for every cell a drag passes over; `on` is the paint value.
  final void Function(int step, bool on)? onPaintStep;
  final double height;

  @override
  State<TrackLane> createState() => _TrackLaneState();
}

class _TrackLaneState extends State<TrackLane> {
  bool? _paintOn;
  int _lastPainted = -1;

  int _stepAt(Offset local, double w) =>
      widget.firstStep + (local.dx / w * widget.stepCount).floor().clamp(0, widget.stepCount - 1);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final paint = widget.onPaintStep;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => widget.onTapStep(_stepAt(d.localPosition, w)),
        onLongPressStart: (d) => widget.onLongPressStep(_stepAt(d.localPosition, w)),
        onHorizontalDragStart: paint == null
            ? null
            : (d) {
                final s = _stepAt(d.localPosition, w);
                _paintOn = widget.track.noteAt(s) == null;
                _lastPainted = s;
                paint(s, _paintOn!);
              },
        onHorizontalDragUpdate: paint == null
            ? null
            : (d) {
                final s = _stepAt(d.localPosition, w);
                if (s == _lastPainted || _paintOn == null) return;
                _lastPainted = s;
                paint(s, _paintOn!);
              },
        onHorizontalDragEnd: paint == null ? null : (_) => _paintOn = null,
        child: CustomPaint(
          size: Size(w, widget.height),
          painter: _LanePainter(widget.track, widget.pattern, widget.currentStep, widget.firstStep, widget.stepCount),
        ),
      );
    });
  }
}

class _LanePainter extends CustomPainter {
  _LanePainter(this.track, this.pattern, this.currentStep, this.first, this.count);
  final Track track;
  final Pattern pattern;
  final int currentStep;
  final int first;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final stepW = size.width / count;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(9));
    canvas.drawRRect(r, Paint()..color = track.muted ? Bg.lane.withValues(alpha: 0.5) : Bg.lane);

    final beatPaint = Paint()..color = Bg.line..strokeWidth = 1;
    final barPaint = Paint()..color = Bg.muted.withValues(alpha: 0.6)..strokeWidth = 1;
    for (var s = 4; s < count; s += 4) {
      final x = s * stepW;
      canvas.drawLine(Offset(x, 5), Offset(x, size.height - 5), (first + s) % 16 == 0 ? barPaint : beatPaint);
    }

    const pad = 3.0;
    final base = track.muted ? Bg.limeDim : Bg.lime;
    final keyLow = 24 + pattern.keyRoot; // editor's lowest row (octave 0)
    for (final n in track.notes) {
      final s0 = n.step - first;
      final s1 = s0 + n.length;
      if (s1 <= 0 || s0 >= count) continue;
      final x0 = s0.clamp(0, count) * stepW + pad;
      final x1 = s1.clamp(0, count) * stepW - pad;
      double y0, y1;
      if (track.isDrum) {
        final h = size.height - pad * 2;
        final vh = h * (0.45 + 0.55 * (n.velocity / 127));
        y0 = (size.height - vh) / 2;
        y1 = y0 + vh;
      } else {
        // 25 semitone slots across two octaves; top = high
        final slot = (n.pitch - keyLow).clamp(0, 24);
        final slotH = (size.height - pad * 2) / 25;
        y1 = size.height - pad - slot * slotH;
        y0 = y1 - slotH * 5;
        if (y0 < pad) y0 = pad;
        if (y1 - y0 < 5) y1 = y0 + 5;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(x0, y0, x1, y1), const Radius.circular(5)),
        Paint()..color = base.withValues(alpha: 0.55 + 0.45 * n.velocity / 127),
      );
    }

    final ps = currentStep - first;
    if (ps >= 0 && ps < count) {
      final x = ps * stepW + stepW / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()..color = Bg.playhead..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_LanePainter old) => true;
}
