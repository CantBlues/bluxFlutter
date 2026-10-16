import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

/// The signature red bar sweeping left and right across a dark track.
class KittScanner extends StatefulWidget {
  const KittScanner({
    super.key,
    this.height = 24,
    this.duration = const Duration(milliseconds: 1900),
    this.active = true,
  });

  final double height;
  final Duration duration;

  /// false parks the bar dark in the centre (system standby)
  final bool active;

  @override
  State<KittScanner> createState() => _KittScannerState();
}

class _KittScannerState extends State<KittScanner> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant KittScanner old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active) {
      _c.stop();
      _c.value = 0.5;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _ScannerPainter(
                    t: widget.active ? Curves.easeInOut.transform(_c.value) : .5,
                    active: widget.active,
                    height: widget.height))),
      ),
    );
  }
}

/// LED dot-matrix scanner: a row of discrete red lamps whose head sweeps
/// left and right, each bulb brightening with distance falloff + flicker.
class _ScannerPainter extends CustomPainter {
  _ScannerPainter({required this.t, required this.active, required this.height});
  final double t;
  final bool active;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.height / 2));

    // recessed lamp plate
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF120405));
    canvas.drawRRect(
        rrect.inflate(-.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x55FF3B30));

    // LED lattice geometry
    final pitch = (size.height * .52).clamp(7.0, 12.0);
    final ledR = pitch * .30;
    final n = ((size.width - pitch) / pitch).floor().clamp(12, 200);
    final x0 = (size.width - (n - 1) * pitch) / 2;
    final sigma = pitch * 2.4; // falloff of the sweeping head

    // parked centre when inactive; `t` is already eased by the widget
    final sweep = active ? t : .5;
    final head = x0 + (n - 1) * pitch * sweep;

    canvas.save();
    canvas.clipRRect(rrect);

    // 1) soft halo layer under the lit bulbs
    if (active) {
      final glow = Paint()
        ..color = KittColors.red
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, pitch * .9);
      for (var i = 0; i < n; i++) {
        final x = x0 + i * pitch;
        final g = _falloff(x, head, sigma);
        if (g > .25) {
          glow.color = KittColors.red.withOpacity(g * .55);
          canvas.drawCircle(Offset(x, size.height / 2), ledR * 2.6, glow);
        }
      }
    }

    // 2) the bulbs themselves
    for (var i = 0; i < n; i++) {
      final x = x0 + i * pitch;
      final c = Offset(x, size.height / 2);
      final g = active ? _falloff(x, head, sigma) : (i == n ~/ 2 ? .12 : 0.0);

      // unlit bulb: dark glass with a faint red tint, always visible
      canvas.drawCircle(c, ledR, Paint()..color = const Color(0xFF2A0A09));

      if (g > .02) {
        // per-bulb micro flicker so the lit ones never look flat
        final flick = .86 + .14 * sin(t * 62 + i * 2.57);
        final lit = g * flick;
        final color = Color.lerp(const Color(0xFF8F1710), KittColors.redBright, lit)!;
        canvas.drawCircle(c, ledR * (1 + .28 * lit), Paint()..color = color);
        // inner hot core on the head bulbs
        if (lit > .75) {
          canvas.drawCircle(
              c,
              ledR * .55,
              Paint()
                ..color = const Color(0xFFFFB3AC).withOpacity((lit - .75) * 3.2)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
        }
      }
      // glass socket ring for texture
      canvas.drawCircle(
          c,
          ledR * 1.32,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6
            ..color = const Color(0x22FF3B30));
    }
    canvas.restore();
  }

  static double _falloff(double x, double head, double sigma) {
    final d = (x - head) / sigma;
    return exp(-d * d / 2);
  }

  @override
  bool shouldRepaint(_ScannerPainter old) => old.t != t || old.active != active;
}

/// Chamfered-corner cockpit panel with a module label header.
class KittPanel extends StatelessWidget {
  const KittPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.accent = KittColors.red,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 14, 14),
    this.fill = KittColors.panelFill,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final Color accent;
  final EdgeInsets padding;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      return Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _PanelPainter(accent: accent, fill: fill))),
        Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        BlinkDot(color: accent, size: 6),
                        const SizedBox(width: 8),
                        Text(title!.toUpperCase(), style: KittStyle.label(size: 13, color: accent)),
                        const Spacer(),
                        if (trailing != null) trailing!,
                      ])),
                child,
              ],
            )),
      ]);
    });
  }
}

Path chamferPath(Rect r, double c) {
  final p = Path()
    ..moveTo(r.left + c, r.top)
    ..lineTo(r.right - c, r.top)
    ..lineTo(r.right, r.top + c)
    ..lineTo(r.right, r.bottom - c)
    ..lineTo(r.right - c, r.bottom)
    ..lineTo(r.left + c, r.bottom)
    ..lineTo(r.left, r.bottom - c)
    ..lineTo(r.left, r.top + c)
    ..close();
  return p;
}

class _PanelPainter extends CustomPainter {
  _PanelPainter({required this.accent, required this.fill});
  final Color accent;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final p = chamferPath(Offset.zero & size, 12);
    canvas.drawPath(p, Paint()..color = fill);
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withOpacity(.4));
  }

  @override
  bool shouldRepaint(_PanelPainter old) => old.accent != accent || old.fill != fill;
}

/// Small pulsing status lamp.
class BlinkDot extends StatefulWidget {
  const BlinkDot({super.key, this.color = KittColors.red, this.size = 8, this.period = const Duration(milliseconds: 1200)});
  final Color color;
  final double size;
  final Duration period;

  @override
  State<BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(.3 + .7 * Curves.easeInOut.transform(_c.value)),
                boxShadow: [BoxShadow(color: widget.color.withOpacity(.8), blurRadius: 6)])));
  }
}

/// Arc gauge, 0..1, KITT instrument cluster style.
class KittGauge extends StatefulWidget {
  const KittGauge({
    super.key,
    required this.value,
    this.size = 110,
    this.label,
    this.sub,
    this.color = KittColors.red,
    this.maxValue = 1,
    this.unit = '',
  });

  final double value;
  final double maxValue;
  final double size;
  final String? label;
  final String? sub;
  final String unit;
  final Color color;

  @override
  State<KittGauge> createState() => _KittGaugeState();
}

class _KittGaugeState extends State<KittGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late Animation<double> _anim =
      Tween<double>(begin: 0, end: _target).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  double get _target =>
      widget.maxValue <= 0 ? 0 : (widget.value / widget.maxValue).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant KittGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.maxValue != widget.maxValue) {
      _anim = Tween<double>(begin: _anim.value, end: _target)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(alignment: Alignment.center, children: [
          RepaintBoundary(
              child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => CustomPaint(
                      size: Size.square(widget.size),
                      painter: _GaugePainter(
                          t: _anim.value, color: widget.color, ticks: _target)))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${widget.value.toStringAsFixed(widget.value % 1 == 0 ? 0 : 1)}${widget.unit}',
                style: KittStyle.value(size: widget.size * .22, color: widget.color)),
            if (widget.sub != null)
              Text(widget.sub!.toUpperCase(),
                  style: KittStyle.label(size: 12, color: KittColors.textDim, spacing: 1)),
          ]),
        ]));
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.t, required this.color, required this.ticks});
  final double t; // animated sweep fraction
  final double ticks; // target fraction for tick illumination
  final Color color;

  static const _start = pi * .75; // 225deg
  static const _sweep = pi * 1.5; // 270deg travel

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 8;
    final center = size.center(Offset.zero);
    final arcRect = Rect.fromCircle(center: center, radius: r);

    // dial background arc
    canvas.drawArc(
        arcRect,
        _start,
        _sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x33FFFFFF));

    // value arc with glow
    canvas.drawArc(
        arcRect,
        _start,
        _sweep * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // tick marks
    for (var i = 0; i <= 12; i++) {
      final f = i / 12;
      final a = _start + _sweep * f;
      final lit = f <= ticks;
      final inner = r - (i % 3 == 0 ? 12 : 8);
      canvas.drawLine(
          center + Offset(cos(a), sin(a)) * (r - 4),
          center + Offset(cos(a), sin(a)) * inner,
          Paint()
            ..strokeWidth = i % 3 == 0 ? 2 : 1
            ..color = lit ? color.withOpacity(.9) : KittColors.textFaint);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.t != t || old.color != color || old.ticks != ticks;
}

/// Tappable dashboard module tile.
class KittTile extends StatelessWidget {
  const KittTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.disabled = false,
    this.accent = KittColors.red,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool disabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fg = disabled ? KittColors.textFaint : accent;
    return Opacity(
        opacity: disabled ? .45 : 1,
        child: GestureDetector(
            onTap: disabled ? null : onTap,
            child: KittPanel(
                accent: disabled ? KittColors.textFaint : accent,
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                    width: double.infinity,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Icon(icon ?? Icons.settings_input_component, color: fg, size: 24),
                            if (disabled)
                              Text("需联网",
                                  style: KittStyle.label(size: 11, color: KittColors.amber, spacing: 1)),
                          ]),
                          const SizedBox(height: 10),
                          Text(title.toUpperCase(),
                              style: KittStyle.label(size: 15, color: disabled ? KittColors.textFaint : KittColors.text)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!.toUpperCase(),
                                style: KittStyle.label(size: 12, color: KittColors.textDim)),
                          ],
                        ])))));
  }
}

/// Uppercase section divider with side rules, like a dashboard legend.
class KittSection extends StatelessWidget {
  const KittSection(this.text, {super.key, this.color = KittColors.red});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(height: 1, width: 20, color: color),
      const SizedBox(width: 10),
      Text(text.toUpperCase(), style: KittStyle.label(size: 11, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: color.withOpacity(.3))),
    ]);
  }
}

/// Faint cockpit grid backdrop painted behind page content.
class GridBackdrop extends StatelessWidget {
  const GridBackdrop({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
        decoration: const BoxDecoration(
            gradient: RadialGradient(
                colors: [Color(0xFF0B0B10), KittColors.bg],
                center: Alignment(0, -.6),
                radius: 1.2)),
        child: CustomPaint(painter: _GridPainter(), child: child));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = KittColors.grid
      ..strokeWidth = .5;
    const step = 44.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
