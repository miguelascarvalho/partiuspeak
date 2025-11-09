import 'package:flutter/material.dart';

class LessonButton extends StatelessWidget {
  final String textEn;
  final String textPt;
  final Color color;
  final bool isCompleted;
  final bool isLocked;
  final double width;
  final VoidCallback onPressed;
  final VoidCallback? onIconPressed;

  const LessonButton({
    super.key,
    required this.textEn,
    required this.textPt,
    required this.color,
    required this.isCompleted,
    required this.isLocked,
    required this.width,
    required this.onPressed,
    this.onIconPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isLocked ? Colors.grey.shade600 : color;
    final textOpacity = isLocked ? 0.6 : 1.0;

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: Colors.white,
          shadowColor: isLocked ? Colors.black26 : Colors.black45,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isLocked ? 1 : 4,
        ),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: textOpacity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      textEn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      textPt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: isLocked ? null : onIconPressed,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  isLocked
                      ? Icons.lock
                      : (isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked),
                  color: isLocked
                      ? Colors.white
                      : (isCompleted ? Colors.greenAccent : Colors.white54),
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
