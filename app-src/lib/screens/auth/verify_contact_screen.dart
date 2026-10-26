// Screen where a resident confirms email and mobile with codes.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../services/session.dart';
import '../../widgets/widgets.dart';

/// Shown to a new resident before anything else: confirm the account with one 6-digit code,
/// sent by text message or by email (the person chooses, among the ways that are set up).
class VerifyContactScreen extends StatefulWidget {
  const VerifyContactScreen({super.key});

  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  final _code = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;
  VerifyOptions? _opts;
  String _chan = '';
  String _sentTo = '';
  int _wait = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final o = await session.verifyOptions();
    if (!mounted) return;
    setState(() {
      _opts = o;
      _chan = o.first;
      _error = o.error;
    });
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (_chan.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await session.sendVerificationCode(_chan);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.alreadyDone) return;
    if (r.error != null) {
      setState(() => _error = r.error);
      return;
    }
    _code.clear();
    setState(() {
      _sent = true;
      _sentTo = _chan == 'sms' ? r.phone : r.email;
    });
    _startCountdown(r.cooldown);
  }

  Future<void> _check() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await session.checkVerificationCode(_chan, _code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = _opts;
    final way = _chan == 'sms' ? 'text message' : 'email';
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
                  Text('Verify your account', style: hd(22)),
                  const SizedBox(height: 6),
                  Text(
                    _sent
                        ? 'We sent a code by $way to $_sentTo. Enter it below. It expires in 10 minutes.'
                        : 'For your security, confirm your account. Choose how you want to get your code.',
                    style: TextStyle(color: muted(context), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  if (o == null)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (!o.any)
                    const Text('Verification codes are not available right now. Please try again later.',
                        style: TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600))
                  else if (!_sent) ...[
                    ChannelPicker(
                      smsReady: o.smsReady,
                      emailReady: o.emailReady,
                      value: _chan,
                      phone: o.phone,
                      email: o.email,
                      onChanged: (v) => setState(() => _chan = v),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'Sending…' : 'Send the code')),
                    ),
                  ] else
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _check(),
                      decoration: InputDecoration(
                        labelText: '6-digit code',
                        prefixIcon: Icon(_chan == 'sms' ? Icons.sms_outlined : Icons.mail_outline_rounded),
                        counterText: '',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error!, style: const TextStyle(color: danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  if (_sent) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(onPressed: _busy ? null : _check, child: Text(_busy ? 'Checking…' : 'Verify')),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: (_busy || _wait > 0) ? null : _send,
                        child: Text(_wait > 0 ? 'Send a new code in $_wait s' : 'Send a new code'),
                      ),
                    ),
                    if (o != null && o.smsReady && o.emailReady)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _busy ? null : () => setState(() { _sent = false; _error = null; }),
                          child: const Text('Send it another way'),
                        ),
                      ),
                  ],
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
