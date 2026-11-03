// The sign-in screen (and the Demo mode card when built as a demo).

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/demo.dart';
import '../../services/links.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _show = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final err = await session.signIn(_email.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  void _forgot() => go(context, const ForgotPasswordScreen());

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      // The background stays fixed; the page scrolls above the keyboard instead.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- building photo as the full-screen background
          Image.asset(
            'assets/images/building.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(color: ink),
          ),
          // dark overlay so the white text stays readable
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [ink.withAlpha(70), ink.withAlpha(140), ink.withAlpha(225)],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 28 + keyboard),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- brand header
                  Reveal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                          decoration: BoxDecoration(color: Colors.white.withAlpha(230), borderRadius: BorderRadius.circular(99)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipOval(
                                child: Image.asset(
                                  'assets/images/logo.jpg',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 32,
                                    height: 32,
                                    color: lav,
                                    child: const Icon(Icons.apartment_rounded, color: ink, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('ResidentHub', style: hd(16, color: ink)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                        Text('Your condominium,\nin your pocket.', style: hd(28, color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(
                          'CITY RESIDENCES CONDOMINIUM CORP.',
                          style: TextStyle(color: Colors.white.withAlpha(225), fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // --- form
                  Reveal(
                    index: 1,
                    child: RCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back!', style: hd(24)),
                          const SizedBox(height: 4),
                          Text('Sign in with the email and password you were given.', style: TextStyle(color: muted(context), fontSize: 13)),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.text,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() => _error = null),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pass,
                            obscureText: !_show,
                            autocorrect: false,
                            enableSuggestions: false,
                            onSubmitted: (_) => _submit(),
                            onChanged: (_) => setState(() => _error = null),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _show = !_show),
                              ),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Signing in…' : 'Continue')),
                          ),
                          if (!kDemo)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (kDemo) ...[
                    Reveal(
                      index: 2,
                      child: PastelCard(
                        color: Pastel.lavender,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kPrototype ? 'Quick access' : 'Demo mode', style: hd(18, color: ink)),
                            const SizedBox(height: 4),
                            const Text(
                              kPrototype ? 'Open the app as an administrator or as a resident.' : 'Everything here is made-up sample data. Nothing is saved to a database, and it resets when you close the page.',
                              style: TextStyle(color: inkSoft, fontSize: 12.5, height: 1.4),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Administrator: admin@demo.test. Resident: resident@demo.test. Password: Demo@1234.',
                              style: TextStyle(color: inkSoft, fontSize: 12.5, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(onPressed: () => startDemo(Role.admin), child: const Text(kPrototype ? 'Continue as Administrator' : 'Try as Administrator')),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => startDemo(Role.resident),
                                child: const Text(kPrototype ? 'Continue as Resident (Maria, Unit 3B)' : 'Try as Resident (Maria, Unit 3B)'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                  Reveal(
                    index: 2,
                    child: PastelCard(
                      color: Pastel.lavender,
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        children: [
                          GlassIcon(Icons.verified_user_outlined, size: 38),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No public sign-up. Accounts are issued by the administration office, which links your email to your confirmed unit.',
                              style: TextStyle(color: inkSoft, fontSize: 12.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Reveal(
                    index: 3,
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => openWebsite(context),
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.language_rounded, size: 18),
                        label: const Text('Visit our website', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
