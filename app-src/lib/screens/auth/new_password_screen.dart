// Screen where a new resident must choose their own password.

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

/// Shown after the administrator created or reset an account: choose your own password first.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _pass = TextEditingController();
  final _conf = TextEditingController();
  bool _show = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _conf.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final err = await session.setFirstPassword(_pass.text, _conf.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: RCard(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Choose your password', style: hd(22)),
                  const SizedBox(height: 6),
                  Text(
                    'The administrator gave you a temporary password. Choose your own now. Only you will know it.',
                    style: TextStyle(color: muted(context), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pass,
                    obscureText: !_show,
                    onChanged: (_) => setState(() => _error = null),
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                  ),
                  PasswordRulesList(controller: _pass),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _conf,
                    obscureText: !_show,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _save(),
                    decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save and continue')),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: session.signOut, child: const Text('Sign out')),
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
