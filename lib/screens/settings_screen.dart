import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/ads/ads_service.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/utils/routes.dart';
import '../providers/player_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/ads/native_ad_view.dart';
import '../widgets/common/bouncy_button.dart';
import '../widgets/common/game_background.dart';
import '../widgets/game/game_dialogs.dart';
import 'how_to_play_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Responsive.of(context).scale;
    return Scaffold(
      body: GameBackground(
        animate: false,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 12 * s),
                children: [
                  _TitleBar(title: 'Settings', scale: s),
                  SizedBox(height: 20 * s),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) => _Section(
                      title: 'Game',
                      children: [
                        _SwitchRow(
                          icon: Icons.volume_up_rounded,
                          color: const Color(0xFF2C7BF2),
                          label: 'Sound effects',
                          value: settings.sound,
                          onChanged: (v) => settings.sound = v,
                        ),
                        _SwitchRow(
                          icon: Icons.record_voice_over_rounded,
                          color: const Color(0xFFD62FB4),
                          label: 'Voice cheers',
                          value: settings.voice,
                          onChanged: (v) => settings.voice = v,
                        ),
                        _SwitchRow(
                          icon: Icons.vibration_rounded,
                          color: const Color(0xFF12A67A),
                          label: 'Vibration',
                          value: settings.haptics,
                          onChanged: (v) => settings.haptics = v,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  _Section(
                    title: 'Theme',
                    children: [_ThemePicker(scale: s)],
                  ),
                  SizedBox(height: 16 * s),
                  _Section(
                    title: 'More',
                    children: [
                      _ActionRow(
                        icon: Icons.lightbulb_rounded,
                        color: const Color(0xFFFF9500),
                        label: 'How to play',
                        onTap: () => Navigator.of(context).push(fadeRoute(const HowToPlayScreen())),
                      ),
                      _ActionRow(
                        icon: Icons.privacy_tip_rounded,
                        color: const Color(0xFF12A67A),
                        label: 'Privacy Policy',
                        onTap: () => Navigator.of(context).push(fadeRoute(const PrivacyPolicyScreen())),
                      ),
                      // Required by Google in regions with consent laws (EEA, UK).
                      ValueListenableBuilder<bool>(
                        valueListenable: context.read<AdsService>().privacyOptionsRequired,
                        builder: (context, required, _) => required
                            ? _ActionRow(
                                icon: Icons.tune_rounded,
                                color: const Color(0xFF2C7BF2),
                                label: 'Privacy choices (ads)',
                                onTap: () => context.read<AdsService>().showPrivacyOptions(),
                              )
                            : const SizedBox.shrink(),
                      ),
                      _ActionRow(
                        icon: Icons.delete_forever_rounded,
                        color: const Color(0xFFF0306A),
                        label: 'Reset progress',
                        onTap: () => _confirmReset(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 28 * s),
                  Center(
                    child: Text(
                      'MergeSeven v1.0.0',
                      style: TextStyle(color: context.palette.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ),
                  // Native ad; takes no space until it has loaded.
                  const NativeAdView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showGameDialog<bool>(
      context,
      DialogCard(
        title: 'Reset progress?',
        icon: Icons.warning_rounded,
        headerColors: const [Color(0xFFFF8FA3), Color(0xFFD7263D)],
        child: Builder(
          builder: (context) => Column(
            children: [
              Text(
                'Best score, diamonds and stats will be cleared. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.textMuted, fontSize: 16),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'CANCEL',
                      height: 50,
                      fontSize: 17,
                      colors: [context.palette.accent.withValues(alpha: 0.8), context.palette.accent],
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'RESET',
                      height: 50,
                      fontSize: 17,
                      colors: const [Color(0xFFFF8FA3), Color(0xFFD7263D)],
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && context.mounted) {
      context.read<PlayerProvider>().resetAll();
    }
  }
}

class _TitleBar extends StatelessWidget {
  final String title;
  final double scale;
  const _TitleBar({required this.title, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(
          icon: Icons.arrow_back_rounded,
          size: 46 * scale,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        SizedBox(width: 14 * scale),
        Text(
          title,
          style: TextStyle(fontSize: 30 * scale, fontWeight: FontWeight.w700, color: context.palette.textPrimary),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, letterSpacing: 1.5),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.cardBorder, width: 1.5),
            boxShadow: [BoxShadow(color: p.cardBorder, offset: const Offset(0, 4))],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBubble(this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: color, size: 22),
  );
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _IconBubble(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: context.palette.textPrimary),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _IconBubble(icon, color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: context.palette.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  final double scale;
  const _ThemePicker({required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final settings = context.watch<SettingsProvider>();
    const options = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'Auto'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (final (mode, icon, label) in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: BouncyButton(
                  onTap: () => settings.themeMode = mode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: settings.themeMode == mode ? LinearGradient(colors: [p.accent, p.accent2]) : null,
                      color: settings.themeMode == mode ? null : p.barTrack.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: settings.themeMode == mode ? Colors.white : p.textMuted),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: settings.themeMode == mode ? Colors.white : p.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
