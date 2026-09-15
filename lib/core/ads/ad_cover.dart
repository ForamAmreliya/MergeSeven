import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Full-screen cover shown while a full-screen ad is being prepared. It blocks
/// taps so nothing happens underneath, and can briefly show a message.
class AdCover {
  AdCover._(this._entry, this._message);

  final OverlayEntry _entry;
  final ValueNotifier<(String, bool)> _message;
  bool _removed = false;

  static AdCover show(BuildContext context, {String message = 'Loading ad…'}) {
    final state = ValueNotifier<(String, bool)>((message, false));
    final entry = OverlayEntry(builder: (_) => _CoverView(state: state));
    Overlay.of(context, rootOverlay: true).insert(entry);
    return AdCover._(entry, state);
  }

  /// Shows [text] with a warning icon for a moment, then removes the cover.
  Future<void> notice(String text) async {
    if (_removed) return;
    _message.value = (text, true);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    hide();
  }

  void hide() {
    if (_removed) return;
    _removed = true;
    _entry.remove();
    _message.dispose();
  }
}

class _CoverView extends StatelessWidget {
  final ValueNotifier<(String, bool)> state;
  const _CoverView({required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      child: AbsorbPointer(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.cardBorder, width: 2),
            ),
            child: ValueListenableBuilder<(String, bool)>(
              valueListenable: state,
              builder: (context, value, _) {
                final (text, isNotice) = value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNotice)
                      const Icon(Icons.info_rounded, size: 44, color: Color(0xFFFF9500))
                    else
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(strokeWidth: 4, color: p.accent),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.textPrimary),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
