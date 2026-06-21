import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';
import '../../state/app_state.dart';

/// Optional account (App Store 5.1.1(v): never forced). A chooser of Google /
/// Apple / email; email reveals the password form. Email auth is wired to
/// Supabase; Google / Apple need native OAuth config, shown as coming soon.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showEmail = false;
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    // Validate client-side first: catches the common mistakes (empty/malformed
    // fields) with a friendly message instead of firing a pointless network
    // call and surfacing a raw backend error.
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = _creating
          ? 'Password must be at least 6 characters.'
          : 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_creating) {
        await auth.signUp(email: email, password: password);
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
      if (mounted && auth.currentSession != null) {
        _enterApp();
      } else if (mounted) {
        setState(() => _error = 'Check your email to confirm your account, then sign in.');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _soon(String which) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$which sign-in is coming soon.')));

  // Enter the app from sign-in. Sign-in is reachable BEFORE onboarding is done
  // ("I already have an account" on Welcome), so mark onboarding complete first —
  // otherwise the router redirect bounces /home straight back to /welcome.
  void _enterApp() {
    ref.read(prefsProvider).setBool('onboarding_done', true);
    ref.read(onboardingDoneProvider.notifier).state = true;
    context.go('/home');
  }

  // Back, however the user triggers it (system back or the arrow). Collapse the
  // email sub-form first; otherwise pop if we were pushed (from Welcome), or
  // fall back to /home (reached via go() at the end of onboarding — back = skip).
  void _handleBack() {
    if (_showEmail) {
      setState(() => _showEmail = false);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Handle back ourselves: the screen can be reached via push (from Welcome —
    // pop back) OR via go() at the end of onboarding (nothing to pop, so back
    // would do nothing). Also collapse the email sub-form before leaving.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Always present — even when reached via go() from onboarding, where
            // there's nothing to pop, so the user isn't stranded without a back.
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _handleBack,
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              children: [
                const SizedBox(height: 36),
                Center(
                  child: Image.asset(
                    'assets/brand/lactic_icon.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(22)),
                      child: Icon(Icons.mark_chat_read_rounded, size: 40, color: scheme.onPrimary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Welcome back', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text('Sign in to save your progress and pick up where you left off.',
                    textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, height: 1.5)),
                const SizedBox(height: 32),
                if (!_showEmail) ...[
                  _AuthButton(
                    icon: SvgPicture.asset('assets/brand/google_g.svg', width: 22, height: 22),
                    label: 'Continue with Google',
                    onTap: () => _soon('Google'),
                  ),
                  const SizedBox(height: 12),
                  _AuthButton(
                    icon: const Icon(Icons.apple_rounded, size: 24),
                    label: 'Sign in with Apple',
                    onTap: () => _soon('Apple'),
                  ),
                  const SizedBox(height: 12),
                  _AuthButton(
                    icon: const Icon(Icons.mail_outline_rounded, size: 22),
                    label: 'Continue with email',
                    onTap: () => setState(() => _showEmail = true),
                  ),
                  const SizedBox(height: 24),
                  Text('No account needed to try Lactic. You can delete your account at any time in Settings.',
                      textAlign: TextAlign.center, style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.5)),
                ] else ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Password'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: t.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_creating ? 'Create account' : 'Sign in'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() => _creating = !_creating),
                    child: Text(_creating ? 'Have an account? Sign in' : 'New here? Create an account'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showEmail = false),
                    child: const Text('Back to all options'),
                  ),
                ],
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: _enterApp,
                  child: Text('Skip for now', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const _AuthButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: t.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FF.rButton)),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            IconTheme(data: IconThemeData(color: scheme.onSurface), child: icon),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
