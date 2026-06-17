import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/tokens.dart';

/// Optional account (App Store 5.1.1(v): never forced). Email auth is wired to
/// Supabase; Google / Apple need native OAuth config, shown as coming soon.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
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
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = Supabase.instance.client.auth;
    try {
      if (_creating) {
        await auth.signUp(email: _email.text.trim(), password: _password.text);
      } else {
        await auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      }
      if (mounted && auth.currentSession != null) {
        context.pop();
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text('Save your progress', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('Sync your study memory across devices. Optional, you can keep using JCAI without an account.',
                style: TextStyle(color: t.textMuted, height: 1.5)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _soon('Google'),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _soon('Apple'),
              icon: const Icon(Icons.apple_rounded),
              label: const Text('Continue with Apple'),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Divider(color: t.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: TextStyle(color: t.textMuted)),
              ),
              Expanded(child: Divider(color: t.border)),
            ]),
            const SizedBox(height: 20),
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
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _creating = !_creating),
                child: Text(_creating ? 'Have an account? Sign in' : 'New here? Create an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
