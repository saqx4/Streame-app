// Skip Intro Button — appears during detected intro/recap/outro segments
import 'package:flutter/material.dart';
import 'package:streame/core/theme/app_theme.dart';
import 'package:streame/core/repositories/skip_intro_repository.dart';

class SkipIntroButton extends StatefulWidget {
  final SkipInterval? interval;
  final VoidCallback onSkip;

  const SkipIntroButton({
    super.key,
    required this.interval,
    required this.onSkip,
  });

  @override
  State<SkipIntroButton> createState() => _SkipIntroButtonState();
}

class _SkipIntroButtonState extends State<SkipIntroButton> {
  bool _dismissed = false;

  String get _label {
    if (widget.interval == null) return '';
    switch (widget.interval!.type) {
      case 'intro':
      case 'recap':
        return 'Skip Intro';
      case 'outro':
        return 'Skip Outro';
      case 'op':
      case 'mixed-op':
        return 'Skip Opening';
      case 'ed':
      case 'mixed-ed':
        return 'Skip Ending';
      default:
        return 'Skip';
    }
  }

  @override
  void didUpdateWidget(SkipIntroButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interval != oldWidget.interval) {
      _dismissed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.interval == null || _dismissed) return const SizedBox.shrink();

    return Positioned(
      right: 24,
      bottom: 120,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _dismissed = true);
              widget.onSkip();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.skip_next, color: AppTheme.textPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(_label, style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
