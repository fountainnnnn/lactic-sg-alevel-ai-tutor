import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

// ---------------- Help & FAQ ----------------
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});
  static const _faq = [
    ('How are answers grounded?', 'JCAI retrieves real Singapore prelim papers and the SEAB syllabus, then answers from those and cites the sources it used.'),
    ('Is using JCAI allowed by my school?', 'JCAI is a study aid for understanding and practice. It will not write a graded essay or assignment for submission. Always follow your school\'s rules.'),
    ('Why does it sometimes say it is unsure?', 'It is calibrated to be honest. If it cannot ground an answer, it tells you rather than making something up.'),
    ('How is my data used?', 'Your study memory is used only to tailor your tutoring. It is kept private and secure and is never sold.'),
    ('How do I cancel Premium?', 'Manage or cancel anytime from your App Store or Play Store subscription settings.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: _faq
              .map((f) => ExpansionTile(
                    shape: const Border(),
                    title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(f.$2, style: TextStyle(color: context.tokens.textMuted, height: 1.5)),
                      ),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ---------------- Notifications ----------------
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    Widget toggle(String key, String title, String sub) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: prefs.getBool(key) ?? true,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: TextStyle(color: context.tokens.textMuted)),
          onChanged: (v) async {
            await prefs.setBool(key, v);
            (context as Element).markNeedsBuild();
          },
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            toggle('notif_reminders', 'Study reminders', 'A gentle nudge to keep your streak.'),
            toggle('notif_countdown', 'Exam countdowns', 'Updates as your prelims and A-Levels approach.'),
            toggle('notif_updates', 'Product updates', 'New features and improvements.'),
            const SizedBox(height: 12),
            Text('These are optional and you can change them anytime.',
                style: TextStyle(color: context.tokens.textMuted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------- Legal / About (reusable reader) ----------------
class LegalScreen extends StatelessWidget {
  final String title;
  final String body;
  const LegalScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(body, style: TextStyle(color: context.tokens.textMuted, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

const privacyBody =
    'Last updated: June 2026.\n\nJCAI is a study tutor for Singapore A-Level students. We collect only what is needed to tutor you.\n\nWhat is stored\nYour study memory (subjects, topics you find tricky, preferences) is stored on your device. If you sign in, your conversations are stored on our servers so you can access them across devices.\n\nWhat is sent to the AI model\nTo answer a question, your message and study memory are sent securely to our backend and the AI model that generates the response. This is used only to produce your answer.\n\nWhat we never do\nWe never sell your data. We do not use it for advertising.\n\nDeleting your data\nYou can delete your account and associated data from Settings. Local data is cleared on sign out.\n\nContact\nFor any privacy question, contact support from the Help screen.';

const termsBody =
    'Last updated: June 2026.\n\nBy using JCAI you agree to these terms.\n\nWhat JCAI is\nJCAI is a study aid. It helps you understand concepts, practise, and check your own work. It is not a substitute for your teacher, and it will not complete graded work for submission on your behalf.\n\nAccuracy\nJCAI aims to be accurate and grounded, but it can make mistakes. Always verify important facts (such as what is examinable) with your teacher or SEAB. Any marks or grades it suggests are indicative only.\n\nAcceptable use\nUse JCAI for your own learning. Do not use it to cheat or to produce harmful content.\n\nSubscriptions\nPremium is billed through your app store and can be cancelled there.\n\nChanges\nWe may update these terms; continued use means you accept the changes.';

const aboutBody =
    'JCAI is a personal A-Level tutor for Singapore Junior College students, grounded in real prelim papers and the SEAB syllabus.\n\nVersion 0.1.0\n\nMade with care to help students learn, not to do the work for them.';

// ---------------- Delete account ----------------
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _busy = false;

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    final prefs = ref.read(prefsProvider);
    await prefs.remove('memory_md');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your local data was cleared and you were signed out.')));
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: t.danger, size: 36),
              const SizedBox(height: 12),
              Text('This is permanent', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Deleting your account removes your conversations and study memory. This cannot be undone. Your local data on this device will be cleared and you will be signed out.',
                style: TextStyle(color: t.textMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: const Text('I understand this cannot be undone'),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.danger),
                onPressed: (!_confirmed || _busy) ? null : _delete,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Delete account'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }
}
