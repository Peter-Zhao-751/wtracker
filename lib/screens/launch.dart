import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LaunchScreen extends StatelessWidget {
  final String wordmarkSvg;
  const LaunchScreen({super.key, required this.wordmarkSvg});

  /// Matches the wordmark SVG's card fill (`#0a0a0a`) so the card blends
  /// into the background and only the cream "w" + orange TRACKER read.
  static const Color bg = Color(0xFF0A0A0A);

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
                    wordmarkSvg,
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
