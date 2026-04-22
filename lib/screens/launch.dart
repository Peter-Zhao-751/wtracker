import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LaunchScreen extends StatelessWidget {
  final String wordmarkSvg;
  const LaunchScreen({super.key, required this.wordmarkSvg});

  static const Color bg = Color(0xFF0A0A0A);

  /// Swap the raw SVG's card (`#0a0a0a`) and "w" (`#F3F0E8`) fills so the
  /// card reads cream on the black launch background — must match the
  /// native splash PNG/PDF.
  static String _whiteVariant(String raw) {
    const sentinel = '__LAUNCH_INK__';
    return raw
        .replaceAll('#0a0a0a', sentinel)
        .replaceAll('#F3F0E8', '#0A0A0A')
        .replaceAll(sentinel, '#F3F0E8');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              Positioned(
                top: c.maxHeight * 0.3,
                left: 0,
                right: 0,
                child: Center(
                  child: SvgPicture.string(
                    _whiteVariant(wordmarkSvg),
                    width: c.maxWidth * 0.7,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
