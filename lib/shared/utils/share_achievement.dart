import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';

// ─── Public API ───────────────────────────────────────────────────────────────

/// Renders a 1080×1080 PNG share card and opens the native share sheet.
Future<void> shareAchievementImage(
  BuildContext context, {
  required String title,
  required String subtitle,
  IconData? icon,
  String? topEmoji,
}) async {
  final key = GlobalKey();

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: 0,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 360,
          height: 360,
          child: RepaintBoundary(
            key: key,
            child: _ShareCard(
              title: title,
              subtitle: subtitle,
              icon: icon,
              topEmoji: topEmoji,
            ),
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(entry);

  // Wait two frames so layout + paint complete.
  await _waitFrames(2);

  try {
    final rb = key.currentContext?.findRenderObject();
    if (rb is! RenderRepaintBoundary) {
      entry.remove();
      return;
    }

    // pixelRatio 3.0 → 360 * 3 = 1080 px
    final image = await rb.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      entry.remove();
      return;
    }

    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/logro_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);

    entry.remove();

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject: title,
    );
  } catch (_) {
    entry.remove();
    rethrow;
  }
}

Future<void> _waitFrames(int count) {
  final completer = Completer<void>();
  void schedule(int remaining) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (remaining <= 1) {
        completer.complete();
      } else {
        schedule(remaining - 1);
      }
    });
  }
  schedule(count);
  return completer.future;
}

// ─── Share Card Widget ────────────────────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? topEmoji;

  const _ShareCard({
    required this.title,
    required this.subtitle,
    this.icon,
    this.topEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 360,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradientPrimary,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null)
                  Icon(icon, size: 52, color: Colors.white)
                else
                  Text(
                    topEmoji ?? '🏆',
                    style: const TextStyle(fontSize: 52),
                  ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.80),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'HABIT OS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.50),
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
