import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/repositories/repositories.dart';
import '../../shared/widgets/reading_widgets.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() => _message = 'Check your email if a confirmation was sent.');
      }
    } on AuthUnavailable catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final user = ref.watch(authStateProvider).value;
    final auth = ref.watch(authRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ACCOUNT')),
      body: ReadingWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text('Account', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            if (!config.useSupabase)
              Text(
                'Sample devotions do not need an account. Add SUPABASE_URL and SUPABASE_ANON_KEY to enable email, Google, and Apple sign-in.',
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else if (user != null)
              Text(
                'Signed in as ${user.email ?? user.id}.',
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else
              Text(
                'Sign in to sync preferences and saved devotions. Reading still works without an account.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => auth.signInWithEmail(
                        email: _email.text.trim(),
                        password: _password.text,
                      ),
                    ),
              child: const Text('Sign in with email'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => auth.signUpWithEmail(
                        email: _email.text.trim(),
                        password: _password.text,
                      ),
                    ),
              child: const Text('Create account'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
              child: const Text('Continue with Google'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(auth.signInWithApple),
              child: const Text('Continue with Apple'),
            ),
            if (user != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _run(auth.signOut),
                child: const Text('Sign out'),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: AppTheme.sans,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
