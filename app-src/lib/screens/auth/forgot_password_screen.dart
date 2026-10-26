// Forgot password: ask for the email, enter the code, set a new password.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

/// Forgot password: one code is sent by text message or by email (the person chooses, among the
/// ways that are set up). With the code the person chooses a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false, _sent = false, _show = false;
  String? _error;
  VerifyOptions? _opts;
  String _chan = '';
  int _wait = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var o = await session.resetOptions();
    // if the server could not be asked, offer both and let the server answer
    if (o.error != null) o = const VerifyOptions(emailReady: true, smsReady: true);
    if (!mounted) return;
    setState(() {
      _opts = o;
      _chan = o.first;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  void _countdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _request() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await session.requestPasswordReset(_email.text, _chan);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _sent = true;
    });
    if (err == null) _countdown(60);
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await session.confirmPasswordReset(_email.text, _chan, _code.text, _pw.text, _pw2.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) {
      final m = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      m.hideCurrentSnackBar();
      m.showSnackBar(const SnackBar(content: Text('Password changed. Sign in with your new password.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Forgot password',
      subtitle: 'Choose how to get a code. It goes to the email or mobile number on file for your account, so nobody else can take it over.',
      children: [
        RCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _email,
                enabled: !_sent,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() => _error = null),
                decoration: const InputDecoration(labelText: 'Email of your account', prefixIcon: Icon(Icons.alternate_email_rounded)),
              ),
              if (!_sent) ...[
                const SizedBox(height: 14),
                if (_opts == null)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else if (!_opts!.any)
                  const Text('Verification codes are not available right now. Please contact the administration office.',
                      style: TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600))
                else ...[
                  ChannelPicker(
                    smsReady: _opts!.smsReady,
                    emailReady: _opts!.emailReady,
                    value: _chan,
                    onChanged: (v) => setState(() => _chan = v),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(onPressed: _busy ? null : _request, child: Text(_busy ? 'Sending…' : 'Send the code')),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  'If that email belongs to an account, we sent a code by ${_chan == 'sms' ? 'text message' : 'email'}. The code expires in 10 minutes.',
                  style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: '6-digit code',
                    prefixIcon: Icon(_chan == 'sms' ? Icons.sms_outlined : Icons.mail_outline_rounded),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pw,
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
                PasswordRulesList(controller: _pw),
                const SizedBox(height: 10),
                TextField(
                  controller: _pw2,
                  obscureText: !_show,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _confirm(),
                  decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset_rounded)),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              if (_sent) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(onPressed: _busy ? null : _confirm, child: Text(_busy ? 'Saving…' : 'Change password')),
                ),
                TextButton(
                  onPressed: (_busy || _wait > 0) ? null : _request,
                  child: Text(_wait > 0 ? 'Send a new code in $_wait s' : 'Send a new code'),
                ),
                if (_opts != null && _opts!.smsReady && _opts!.emailReady)
                  TextButton(
                    onPressed: _busy ? null : () => setState(() { _sent = false; _error = null; }),
                    child: const Text('Send it another way'),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'No code arrived? Contact the administration office. They can give you a temporary password.',
            style: TextStyle(color: muted(context), fontSize: 12.5, height: 1.4),
          ),
        ),
      ],
    );
  }
}
