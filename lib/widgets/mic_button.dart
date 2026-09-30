import 'package:flutter/material.dart';

class MicButton extends StatelessWidget {
  final bool listening;
  final bool active;
  final double level;
  final VoidCallback onPressed;

  const MicButton({
    super.key,
    required this.listening,
    required this.active,
    required this.level,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = listening ? cs.error : cs.primary;
    final fg = listening ? cs.onError : cs.onPrimary;
    final halo = listening ? 1.0 + level * 0.6 : 1.0;

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedScale(
            scale: halo,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg.withValues(alpha: listening ? 0.25 : 0),
              ),
            ),
          ),
          Material(
            color: bg,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: fg,
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
