// Everything about the signed-in person: sign in/out, create accounts, verification codes, password reset. Talks to Supabase Auth and the Edge Functions.

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/core.dart';
import 'cloud_sync.dart';
import 'demo.dart';
import 'supabase_config.dart';

/// The result of an account action: an error message, or (for new/reset accounts) the temporary password.
class AccountResult {
  final String? error;
  final String? password;
  const AccountResult({this.error, this.password});
}

/// Where the verification codes were sent, or why they could not be sent.
class VerifyStart {
  final String? error;
  final String email, phone;
  final int cooldown;
  final bool alreadyDone;
  const VerifyStart({this.error, this.email = '', this.phone = '', this.cooldown = 60, this.alreadyDone = false});
}

/// Which ways of getting a code are set up (text message and/or email), and where a code would go.
class VerifyOptions {
  final String? error;
  final bool emailReady, smsReady, verified;
  final String email, phone;
  const VerifyOptions({this.error, this.emailReady = false, this.smsReady = false, this.verified = false, this.email = '', this.phone = ''});
  bool get any => emailReady || smsReady;
  /// "sms" when text messages are set up, else "email", else "".
  String get first => smsReady ? 'sms' : (emailReady ? 'email' : '');
}

/// Signing in and out with Supabase Auth, the signed-in person's profile, and
/// the administrator's account tools (create a resident account, reset a password, ...).
class SessionService {
  bool ready = false;
  int _failed = 0;
  DateTime? _lockedUntil;

  SupabaseClient get _c => Supabase.instance.client;

  /// Starts Supabase and signs the person in again if their last sign-in is still valid.
  Future<void> init() async {
    if (kDemo || !cloudConfigured) {
      app.finishBoot();
      return;
    }
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      ready = true;
    } catch (_) {
      app.finishBoot();
      return;
    }
    _c.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut && app.role != null) {
        unawaited(cloud.end());
        app.clearSession();
      }
    });
    if (_c.auth.currentSession != null) {
      final err = await _enter();
      if (err != null) {
        try {
          await _c.auth.signOut();
        } catch (_) {}
        app.finishBoot();
      }
    } else {
      app.finishBoot();
    }
  }

  /// Loads the profile of the signed-in account and opens the right side of the app.
  Future<String?> _enter() async {
    final user = _c.auth.currentUser;
    if (user == null) return 'Please sign in.';
    try {
      final p = await _c.from('profiles').select().eq('id', user.id).maybeSingle();
      if (p == null) return 'This account is not set up yet. Ask the administrator.';
      if (p['suspended'] == true) return 'This account has been suspended. Contact the administrator.';
      final role = p['role'] == 'admin' ? Role.admin : Role.resident;
      final unit = (p['unit'] ?? '').toString();
      if (role == Role.resident && unit.isEmpty) {
        return 'No unit is assigned to this account yet. Ask the administrator.';
      }
      app.enterSession(
        role: role,
        id: user.id,
        name: (p['name'] ?? '').toString(),
        email: (p['email'] ?? user.email ?? '').toString(),
        phone: (p['phone'] ?? '').toString(),
        unit: unit,
        mustChange: p['must_change_password'] == true,
        verified: p['contact_verified_at'] != null,
      );
      // A resident sees nothing until the email and mobile number are verified.
      if (app.contactVerified) unawaited(cloud.begin());
      if (role == Role.admin) unawaited(loadAccounts());
      return null;
    } catch (_) {
      return 'Could not reach the server. Check your internet connection and try again.';
    }
  }

  /// Returns an error message, or null when sign-in worked.
  Future<String?> signIn(String emailRaw, String pass) async {
    if (kDemo) return demoSignIn(emailRaw, pass);
    final email = emailRaw.trim().toLowerCase();
    if (!ready) return 'The app is not connected to the database.';
    if (email.isEmpty) return 'Enter your email.';
    if (pass.isEmpty) return 'Enter your password.';
    final lock = _lockedUntil;
    if (lock != null && DateTime.now().isBefore(lock)) {
      return 'Too many failed attempts. Please wait a minute and try again.';
    }
    try {
      await _c.auth.signInWithPassword(email: email, password: pass);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('banned')) return 'This account has been suspended. Contact the administrator.';
      if (m.contains('invalid') || m.contains('credentials')) {
        _failed++;
        if (_failed >= 5) {
          _failed = 0;
          _lockedUntil = DateTime.now().add(const Duration(minutes: 1));
          return 'Too many failed attempts. Please wait a minute and try again.';
        }
        return "Incorrect email or password. If you don't have an account yet, ask the administrator to create one.";
      }
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your internet connection and try again.';
    }
    _failed = 0;
    _lockedUntil = null;
    final err = await _enter();
    if (err != null) {
      try {
        await _c.auth.signOut();
      } catch (_) {}
    }
    return err;
  }

  Future<void> signOut() async {
    if (kDemo) {
      app.clearSession();
      return;
    }
    // Never get stuck waiting for the server: a few seconds at most, then clear this device's sign-in.
    try {
      await cloud.end().timeout(const Duration(seconds: 3));
    } catch (_) {}
    app.clearSession();
    try {
      await _c.auth.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        await _c.auth.signOut(scope: SignOutScope.local).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }

  // ------------------------------------------------------------ own account

  /// Saves the name (and, for the administrator, the mobile number) of the signed-in person.
  /// A resident's number is verified, so only the administrator can change it.
  Future<String?> saveProfile(String name, String phone) async {
    if (name.trim().isEmpty) return 'Enter your name.';
    final admin = app.role == Role.admin;
    final ph = admin ? phone.trim() : (app.me?.phone ?? '');
    if (admin && ph.isNotEmpty && !AppState.validMobile(AppState.normalizePhone(ph))) {
      return 'Enter a valid mobile number, e.g. 0917 555 0112.';
    }
    if (!kDemo) {
      try {
        await _c.from('profiles').update({'name': name.trim(), if (admin) 'phone': ph}).eq('id', app.userId);
      } catch (_) {
        return 'Could not save. Check your internet connection and try again.';
      }
    }
    app.setMyProfile(name.trim(), ph);
    return null;
  }

  // ------------------------------------------------------------ verifying email + mobile

  Future<Map<String, dynamic>> _verify(Map<String, dynamic> body) async {
    try {
      final r = await _c.functions.invoke('verify-contact', body: body);
      final d = r.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return {'error': 'Unexpected reply from the server.'};
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] != null) return {'error': d['error'].toString()};
      return {'error': 'The server could not do that (${e.status}).'};
    } catch (_) {
      return {'error': 'Could not reach the server. Check your internet connection.'};
    }
  }

  /// Which ways of getting a code are set up, and where a code would go (masked).
  Future<VerifyOptions> verifyOptions() async {
    final r = await _verify({'action': 'options'});
    if (r['error'] != null) return VerifyOptions(error: r['error'].toString());
    if (r['verified'] == true) {
      await _finishVerification();
      return const VerifyOptions(verified: true);
    }
    return VerifyOptions(
      emailReady: r['emailReady'] == true,
      smsReady: r['smsReady'] == true,
      email: (r['email'] ?? '').toString(),
      phone: (r['phone'] ?? '').toString(),
    );
  }

  /// Sends one code the way the person chose ('sms' or 'email'). Returns where it went or an error.
  Future<VerifyStart> sendVerificationCode(String channel) async {
    final r = await _verify({'action': 'send', 'channel': channel});
    if (r['error'] != null) return VerifyStart(error: r['error'].toString());
    if (r['verified'] == true) {
      await _finishVerification();
      return const VerifyStart(alreadyDone: true);
    }
    return VerifyStart(
      email: (r['email'] ?? '').toString(),
      phone: (r['phone'] ?? '').toString(),
      cooldown: (r['cooldown'] is num) ? (r['cooldown'] as num).toInt() : 60,
    );
  }

  /// Checks the code. Returns an error message, or null when the account is verified.
  Future<String?> checkVerificationCode(String channel, String code) async {
    final r = await _verify({'action': 'check', 'channel': channel, 'code': code.trim()});
    if (r['error'] != null) return r['error'].toString();
    await _finishVerification();
    return null;
  }

  // ------------------------------------------------------------ forgot password (not signed in)

  Future<Map<String, dynamic>> _reset(Map<String, dynamic> body) async {
    try {
      final r = await _c.functions.invoke('reset-password', body: body);
      final d = r.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return {'error': 'Unexpected reply from the server.'};
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] != null) return {'error': d['error'].toString()};
      return {'error': 'The server could not do that (${e.status}).'};
    } catch (_) {
      return {'error': 'Could not reach the server. Check your internet connection.'};
    }
  }

  /// Which ways of getting a reset code are set up. Nothing about any account is revealed.
  Future<VerifyOptions> resetOptions() async {
    if (kDemo) return const VerifyOptions(error: kDemoOff);
    final r = await _reset({'action': 'options'});
    if (r['error'] != null) return VerifyOptions(error: r['error'].toString());
    return VerifyOptions(emailReady: r['emailReady'] == true, smsReady: r['smsReady'] == true);
  }

  /// Asks for a password reset: one code goes the way the person chose ('sms' or 'email').
  /// Returns an error, or null. The answer is the same whether or not the email has an account.
  Future<String?> requestPasswordReset(String emailRaw, String channel) async {
    if (kDemo) return kDemoOff;
    final email = emailRaw.trim().toLowerCase();
    if (!ready) return 'The app is not connected to the database.';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) return 'Enter the email of your account.';
    final r = await _reset({'action': 'request', 'email': email, 'channel': channel});
    return r['error']?.toString();
  }

  /// Checks the code and sets the new password. Returns an error, or null when it worked.
  Future<String?> confirmPasswordReset(String emailRaw, String channel, String code, String nw, String conf) async {
    if (kDemo) return kDemoOff;
    final bad = _checkNew(nw, conf);
    if (bad != null) return bad;
    final r = await _reset({
      'action': 'confirm',
      'email': emailRaw.trim().toLowerCase(),
      'channel': channel,
      'code': code.trim(),
      'newPassword': nw,
    });
    return r['error']?.toString();
  }

  Future<void> _finishVerification() async {
    app.contactVerifiedNow();
    unawaited(cloud.begin());
  }

  /// Change password: the current password is checked first.
  Future<String?> changePassword(String cur, String nw, String conf) async {
    if (kDemo) return kDemoOff;
    final email = app.role == Role.admin ? app.adminEmail : (app.me?.email ?? '');
    if (cur.isEmpty) return 'Enter your current password.';
    final bad = _checkNew(nw, conf);
    if (bad != null) return bad;
    try {
      await _c.auth.signInWithPassword(email: email, password: cur);
    } on AuthException {
      return "Current password doesn't match.";
    } catch (_) {
      return 'Could not reach the server. Check your internet connection and try again.';
    }
    return _setPassword(nw);
  }

  /// The first password after the administrator created or reset the account.
  Future<String?> setFirstPassword(String nw, String conf) async {
    final bad = _checkNew(nw, conf);
    if (bad != null) return bad;
    return _setPassword(nw);
  }

  String? _checkNew(String nw, String conf) {
    final rule = passwordProblem(nw);
    if (rule != null) return rule;
    if (nw != conf) return "New password and confirmation don't match.";
    return null;
  }

  Future<String?> _setPassword(String nw) async {
    try {
      await _c.auth.updateUser(UserAttributes(password: nw));
      await _c.from('profiles').update({'must_change_password': false}).eq('id', app.userId);
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save. Check your internet connection and try again.';
    }
    app.passwordChanged();
    return null;
  }

  // ------------------------------------------------------------ administrator tools

  /// Reads all resident accounts (Manage access).
  Future<void> loadAccounts() async {
    try {
      final rows = await _c.from('profiles').select().eq('role', 'resident').order('created_at');
      app.setAccounts([
        for (final p in rows)
          Account(
            p['id'].toString(),
            (p['name'] ?? '').toString(),
            (p['email'] ?? '').toString(),
            ((p['phone'] ?? '').toString().isEmpty) ? '—' : p['phone'].toString(),
            (p['unit'] ?? '').toString(),
            'Resident',
            _addedText(p['created_at']),
            suspended: p['suspended'] == true,
            verified: p['contact_verified_at'] != null,
          )
      ]);
    } catch (_) {}
  }

  static String _addedText(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    return d == null ? '' : shortDate(d);
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final r = await _c.functions.invoke('manage-users', body: body);
      final d = r.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return {'error': 'Unexpected reply from the server.'};
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] != null) return {'error': d['error'].toString()};
      return {'error': 'The server could not do that (${e.status}).'};
    } catch (_) {
      return {'error': 'Could not reach the server. Check your internet connection.'};
    }
  }

  /// Creates a resident account. The result carries the temporary password to hand over.
  Future<AccountResult> createResident(String name, String email, String phone, String unit) async {
    if (kDemo) return const AccountResult(error: kDemoOff);
    if (name.trim().isEmpty || email.trim().isEmpty) {
      return const AccountResult(error: 'Full name and email are required.');
    }
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email.trim())) {
      return const AccountResult(error: 'Enter a valid email address.');
    }
    if (unit.trim().isEmpty) return const AccountResult(error: "Assign a unit to confirm this resident's account.");
    if (phone.trim().isNotEmpty && !AppState.validMobile(AppState.normalizePhone(phone))) {
      return const AccountResult(error: 'Enter a valid Philippine mobile number, e.g. 0917 555 0112, or leave it empty.');
    }
    final r = await _call({
      'action': 'create',
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'unit': unit.trim(),
    });
    if (r['error'] != null) return AccountResult(error: r['error'].toString());
    await loadAccounts();
    return AccountResult(password: r['password']?.toString());
  }

  Future<AccountResult> resetPassword(Account a) async {
    if (kDemo) return const AccountResult(error: kDemoOff);
    final r = await _call({'action': 'reset-password', 'userId': a.id});
    if (r['error'] != null) return AccountResult(error: r['error'].toString());
    return AccountResult(password: r['password']?.toString());
  }

  Future<String?> setSuspended(Account a, bool suspended) async {
    if (kDemo) return kDemoOff;
    final r = await _call({'action': 'set-suspended', 'userId': a.id, 'suspended': suspended});
    if (r['error'] != null) return r['error'].toString();
    await loadAccounts();
    return null;
  }

  Future<String?> deleteAccount(Account a) async {
    if (kDemo) return kDemoOff;
    final r = await _call({'action': 'delete', 'userId': a.id});
    if (r['error'] != null) return r['error'].toString();
    await loadAccounts();
    return null;
  }
}

final SessionService session = SessionService();
