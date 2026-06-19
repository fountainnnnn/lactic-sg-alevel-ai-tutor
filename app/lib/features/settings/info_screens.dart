import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

// ---------------- Help & FAQ ----------------
class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});
  static const _faq = [
    ('How are answers grounded?', 'Lactic is built on real Singapore A-Level material and the SEAB syllabus, so explanations follow how topics are actually taught and examined, not generic internet content.'),
    ('Where does your content come from? Is it copyrighted?', 'Our knowledge comes from real Singapore A-Level material: prelim papers, school notes, and the SEAB syllabus. That material is analysed and preprocessed in advance to learn the concepts and patterns, so the original copyrighted content is never uploaded, reproduced, or distributed through the app. You get explanations grounded in how the syllabus is taught and examined, never copies of anyone\'s papers.'),
    ('Is using Lactic allowed by my school?', 'Lactic is a study aid for understanding and practice. It will not write a graded essay or assignment for submission. Always follow your school\'s rules.'),
    ('Why does it sometimes say it is unsure?', 'It is calibrated to be honest. If it cannot ground an answer, it tells you rather than making something up.'),
    ('How is my data used?', 'Your study memory is used only to tailor your tutoring. It is kept private and secure and is never sold.'),
    ('How do I cancel Lactic Plus?', 'Manage or cancel anytime from your App Store or Play Store subscription settings.'),
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
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  // (key, title, subtitle, default)
  static const _items = [
    ('notif_streak', 'Daily streak reminder', 'Keep your study habit going', true),
    ('notif_memory', 'Memory nudges', 'Revisit topics you have been working on', true),
    ('notif_countdown', 'Exam countdown', 'Reminders as your exam gets closer', true),
    ('notif_updates', 'Product updates', 'New features and improvements', false),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final prefs = ref.watch(prefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(FF.rCard),
                border: Border.all(color: t.border),
              ),
              // Transparent Material so the switch-tile ripples paint over the
              // card instead of being hidden by its background color.
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: t.border),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                      value: prefs.getBool(_items[i].$1) ?? _items[i].$4,
                      title: Text(_items[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                      subtitle: Text(_items[i].$3, style: TextStyle(color: t.textMuted)),
                      onChanged: (v) async {
                        await prefs.setBool(_items[i].$1, v);
                        setState(() {});
                      },
                    ),
                  ],
                ],
                ),
              ),
            ),
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
    final t = context.tokens;
    final theme = Theme.of(context);
    // Blocks separated by blank lines; a short first line becomes a heading.
    final blocks = body.split('\n\n').where((b) => b.trim().isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(FF.rCard),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    ..._block(context, blocks[i]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _block(BuildContext context, String block) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final lines = block.split('\n');
    final hasHeading = lines.length > 1 && lines.first.length < 40 && !lines.first.endsWith('.');
    if (hasHeading) {
      return [
        Text(lines.first, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(lines.skip(1).join('\n'), style: TextStyle(color: t.textMuted, height: 1.6)),
      ];
    }
    return [Text(block, style: TextStyle(color: t.textMuted, height: 1.6))];
  }
}

const privacyBody =
    'Last updated: June 2026.\n\nLactic is a study tutor for Singapore A-Level students. We collect only what is needed to tutor you.\n\nWhat is stored\nYour study memory (subjects, topics you find tricky, preferences) is stored on your device. If you sign in, your conversations are stored on our servers so you can access them across devices.\n\nWhat is sent to the AI model\nTo answer a question, your message and study memory are sent securely to our backend and the AI model that generates the response. This is used only to produce your answer.\n\nWhat we never do\nWe never sell your data. We do not use it for advertising.\n\nDeleting your data\nYou can permanently delete your account and all associated data (conversations, uploaded images, study memory, and subscription records) from Settings. Deletion is immediate and cannot be undone. Local data on your device is also cleared when you delete or sign out.\n\nContact\nFor any privacy question, contact support from the Help screen.';

const termsBody =
    'Last updated: June 2026.\n\nBy using Lactic you agree to these terms.\n\nWhat Lactic is\nLactic is a study aid. It helps you understand concepts, practise, and check your own work. It is not a substitute for your teacher, and it will not complete graded work for submission on your behalf.\n\nAccuracy\nLactic aims to be accurate and grounded, but it can make mistakes. Always verify important facts (such as what is examinable) with your teacher or SEAB. Any marks or grades it suggests are indicative only.\n\nAcceptable use\nUse Lactic for your own learning. Do not use it to cheat or to produce harmful content.\n\nSubscriptions\nPremium is billed through your app store and can be cancelled there.\n\nChanges\nWe may update these terms; continued use means you accept the changes.';

const aboutBody =
    'Lactic is a personal A-Level tutor for Singapore Junior College students, grounded in real prelim papers and the SEAB syllabus.\n\nVersion 0.1.0\n\nMade with care to help students learn, not to do the work for them.';

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
    final client = Supabase.instance.client;
    final token = client.auth.currentSession?.accessToken;

    // Signed-in: actually delete server-side data first. Only clear local state /
    // sign out AFTER the server confirms — otherwise we'd tell the user their
    // account is gone while their conversations and uploads still exist.
    if (token != null) {
      String? failure;
      try {
        final resp = await http
            .post(
              Uri.parse(Config.deleteAccountEndpoint),
              headers: {
                'Authorization': 'Bearer $token',
                'apikey': Config.supabasePublishableKey,
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) failure = 'The server returned ${resp.statusCode}.';
      } on TimeoutException {
        failure = 'The request timed out.';
      } catch (_) {
        failure = 'Could not reach the server.';
      }
      if (failure != null) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not delete your account: $failure Please try again.')));
        }
        return;
      }
    }

    try {
      await client.auth.signOut();
    } catch (_) {}
    final prefs = ref.read(prefsProvider);
    await prefs.remove('memory_md');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your account and data were permanently deleted.')));
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
                'Deleting your account permanently removes your conversations, uploaded images, study memory, and subscription records from our servers. This cannot be undone. Your local data on this device will also be cleared and you will be signed out.',
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
