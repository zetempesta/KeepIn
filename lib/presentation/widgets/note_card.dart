import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/note.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.note,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: CustomPaint(
          painter: _KeepInCardPainter(
            backgroundColor: note.backgroundColor,
            isPinned: note.isPinned,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (note.isPinned)
                  const Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 18,
                      color: AppColors.deepBlue,
                    ),
                  ),
                if (note.title.isNotEmpty) ...<Widget>[
                  Text(
                    note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                ],
                if (note.content.isNotEmpty)
                  Text(
                    note.content,
                    maxLines: 7,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                if (note.labels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: note.labels
                        .map(
                          (label) => DecoratedBox(
                            decoration: BoxDecoration(
                              color:
                                  AppColors.pureWhite.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Text(
                                label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeepInCardPainter extends CustomPainter {
  const _KeepInCardPainter({
    required this.backgroundColor,
    required this.isPinned,
  });

  final Color backgroundColor;
  final bool isPinned;

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Offset.zero & size;
    final outerRRect = RRect.fromRectAndRadius(
      outerRect,
      const Radius.circular(26),
    );

    canvas.drawShadow(
      Path()..addRRect(outerRRect),
      AppColors.shadowBlue,
      18,
      false,
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          backgroundColor,
          Color.lerp(backgroundColor, AppColors.pureWhite, 0.2) ??
              backgroundColor,
        ],
      ).createShader(outerRect);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = AppColors.pureWhite.withValues(alpha: 0.92);

    canvas.drawRRect(outerRRect, fillPaint);
    canvas.drawRRect(outerRRect, strokePaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.electricBlue.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.78, size.height * 0.2),
          radius: size.width * 0.34,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.2),
      size.width * 0.34,
      glowPaint,
    );

    if (isPinned) {
      final pinLinePaint = Paint()
        ..color = AppColors.electricBlue.withValues(alpha: 0.24)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(size.width * 0.12, 14),
        Offset(size.width * 0.42, 14),
        pinLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KeepInCardPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.isPinned != isPinned;
  }
}
