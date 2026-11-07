import 'package:flutter/material.dart';

import '../main.dart';
import '../model/pattern.dart';

/// One sequencer row: rounded lane, bar lines, lime pills, playhead.
/// Pill width = note length. On melodic tracks pill height position = pitch
/// within a one-octave window above the pattern key.
class TrackLane extends StatelessWidget {
  const TrackLane({
    super.key,
    required this.track,
    required this.pattern,
    required this.currentStep,
    required this.onTapStep,
    required this.onLongPressStep,
  });

  final Track track;
  final Pattern pattern;
  final int currentStep;
  final void Function(int step) onTapStep;
  final void Function(int step) onLongPressStep;

  @override
  Widget build(BuildContext context) {
    final height = track.isDrum ? 34.0 : 56.0;
    return LayoutBuilder(builder: (context, c) {
      int stepAt(Offset local) =>
          (local.dx / c.maxWidth * pattern.steps).floor().clamp(0, pattern.steps - 1);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => onTapStep(stepAt(d.localPosition)),
        onLongPressStart: (d) => onLongPressStep(stepAt(d.localPosition)),
        child: CustomPaint(
          size: Size(c.maxWidth, height),
          painter: _LanePainter(track, pattern, currentStep),
        ),
      );
    });
  }
}

class _LanePainter extends CustomPainter {
  _LanePainter(this.track, this.pattern, this.currentStep);
  final Track track;
  final Pattern pattern;
  final int currentStep;

  @override
  void paint(Canvas canvas, Size size) {
    final steps = pattern.steps;
    final stepW = size.width / steps;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = track.muted ? Bg.lane.withValues(alpha: 0.5) : Bg.lane);

    // beat & bar lines
    final beatPaint = Paint()..color = Bg.line..strokeWidth = 1;
    final barPaint = Paint()..color = Bg.muted.withValues(alpha: 0.6)..strokeWidth = 1;
    for (var s = 4; s < steps; s += 4) {
      final x = s * stepW;
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), s % 16 == 0 ? barPaint : beatPaint);
    }

    // notes
    final pill = Paint()..color = track.muted ? Bg.limeDim : Bg.lime;
    const pad = 3.0;
    final keyLow = 36 + pattern.keyRoot; // key root in octave 1 (Ableton naming)
    for (final n in track.notes) {
      final x0 = n.step * stepW + pad;
      final x1 = (n.step + n.length) * stepW - pad;
      double y0, y1;
      if (track.isDrum) {
        final h = size.height - pad * 2;
        final vh = h * (0.45 + 0.55 * (n.velocity / 127));
        y0 = (size.height - vh) / 2;
        y1 = y0 + vh;
      } else {
        // 13 semitone slots (root .. root+12) top = high
        final slot = (n.pitch - keyLow).clamp(0, 12);
        final slotH = (size.height - pad * 2) / 13;
        y1 = size.height - pad - slot * slotH;
        y0 = y1 - slotH * 2.2;
        if (y0 < pad) {
          y0 = pad;
        }
      }
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x0, y0, x1, y1),
        Radius.circular(track.isDrum ? 5 : 4),
      );
      pill.color = (track.muted ? Bg.limeDim : Bg.lime).withValues(alpha: 0.55 + 0.45 * n.velocity / 127);
      canvas.drawRRect(rect, pill);
    }

    // playhead
    if (currentStep >= 0) {
      final x = currentStep * stepW + stepW / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          Paint()..color = Bg.playhead..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_LanePainter old) => true;
}
