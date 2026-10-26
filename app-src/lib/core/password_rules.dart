/// The rules a new password must follow (the same rules are checked on the server).
class PasswordRule {
  final String label;
  final bool Function(String) test;
  const PasswordRule(this.label, this.test);
}

final passwordRules = <PasswordRule>[
  PasswordRule('At least 8 characters', (p) => p.length >= 8),
  PasswordRule('An uppercase letter (A-Z)', (p) => RegExp(r'[A-Z]').hasMatch(p)),
  PasswordRule('A lowercase letter (a-z)', (p) => RegExp(r'[a-z]').hasMatch(p)),
  PasswordRule('A number (0-9)', (p) => RegExp(r'\d').hasMatch(p)),
  PasswordRule('A symbol, e.g. ! @ # \$ %', (p) => RegExp(r'[^A-Za-z0-9]').hasMatch(p)),
];

/// The first rule the password does not follow, or null when it follows all of them.
String? passwordProblem(String p) {
  for (final r in passwordRules) {
    if (!r.test(p)) return 'Your new password needs: ${r.label.replaceFirst('A ', 'a ').replaceFirst('An ', 'an ').replaceFirst('At least', 'at least')}.';
  }
  return null;
}
