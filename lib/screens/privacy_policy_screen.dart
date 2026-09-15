import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../widgets/common/bouncy_button.dart';
import '../widgets/common/game_background.dart';

/// In-app privacy policy, readable offline.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// Shown in the "Contact us" section. Replace with your support email
  /// before publishing.
  static const lastUpdated = '15 September 2026';

  static const _sections = [
    _Section(
      icon: Icons.shield_rounded,
      color: Color(0xFF7048F5),
      title: 'Overview',
      body:
          'MergeSeven is a free puzzle game. You do not need an account, and we (the developer) do not '
          'run servers that collect your personal information. To keep the game free, it shows ads '
          'provided by Google AdMob. This page explains what that means for your data.',
    ),
    _Section(
      icon: Icons.phone_android_rounded,
      color: Color(0xFF2C7BF2),
      title: 'What is saved on your device',
      body:
          'To let you continue playing, the game saves a few things only on your phone:\n'
          '• Your current game, best score, top tile and level\n'
          '• Your diamonds and number of games played\n'
          '• Your settings (sound, voice cheers, vibration, theme)\n\n'
          'We never receive this data. "Reset progress" in Settings clears your scores, diamonds and '
          'stats, and uninstalling the app removes everything.',
    ),
    _Section(
      icon: Icons.campaign_rounded,
      color: Color(0xFFFF9500),
      title: 'Advertising (Google AdMob)',
      body:
          'The game shows banner and native ads, and optional video ads when you choose to watch '
          'one for a booster or to continue a game. To show '
          'and measure these ads, Google may collect and process:\n'
          '• Your device\'s advertising ID\n'
          '• IP address and approximate location\n'
          '• Device and app information (model, OS version, language)\n'
          '• How you interact with ads, plus diagnostics\n\n'
          'Google uses this to deliver ads, limit how often you see them, prevent fraud and, where '
          'permitted, show personalised ads. Learn more at '
          'policies.google.com/technologies/partner-sites',
    ),
    _Section(
      icon: Icons.tune_rounded,
      color: Color(0xFF12A67A),
      title: 'Your choices',
      body:
          '• You can reset or delete your advertising ID, or opt out of personalised ads, in your '
          'phone\'s settings (Google > Ads, or Privacy > Ads).\n'
          '• In the EEA, UK and Switzerland you are asked for consent before personalised ads are '
          'shown, and you can change it anytime from "Privacy choices (ads)" in Settings.',
    ),
    _Section(
      icon: Icons.lock_rounded,
      color: Color(0xFF14C3F0),
      title: 'Permissions',
      body:
          'The game uses internet and network-state access only to load ads, and the advertising ID '
          'permission for Google AdMob. Gameplay itself works offline. MergeSeven does not ask for '
          'access to your contacts, photos, camera, microphone, precise location or files.',
    ),
    _Section(
      icon: Icons.child_care_rounded,
      color: Color(0xFFD62FB4),
      title: 'Children',
      body:
          'MergeSeven is intended for a general audience and is not directed at children under 13. '
          'We do not knowingly collect personal information from children. If you believe a child '
          'has provided personal information, please contact us.',
    ),
    _Section(
      icon: Icons.update_rounded,
      color: Color(0xFF7048F5),
      title: 'Changes to this policy',
      body:
          'If this policy changes, the updated version will be shown on this page with a new '
          '"Last updated" date.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = Responsive.of(context).scale;
    return Scaffold(
      body: GameBackground(
        animate: false,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20 * s, 12 * s, 20 * s, 8 * s),
                    child: Row(
                      children: [
                        RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          size: 46 * s,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        SizedBox(width: 14 * s),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(fontSize: 30 * s, fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20 * s, 8 * s, 20 * s, 28 * s),
                      children: [
                        Text(
                          'Last updated: $lastUpdated',
                          style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        const SizedBox(height: 14),
                        for (final section in _sections) ...[
                          _SectionCard(section: section),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Thank you for playing MergeSeven!',
                            style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Section({required this.icon, required this.color, required this.title, required this.body});
}

class _SectionCard extends StatelessWidget {
  final _Section section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.cardBorder, width: 1.5),
        boxShadow: [BoxShadow(color: p.cardBorder, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: section.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(section.icon, color: section.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  section.body,
                  style: TextStyle(fontSize: 15, height: 1.45, color: p.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
