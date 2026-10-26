// The live checklist of password rules.

import 'package:flutter/material.dart';

import '../core/password_rules.dart';
import 'common.dart' show muted;

/// A live checklist under a "new password" field: each rule gets a check mark once the password follows it.
class PasswordRulesList extends StatelessWidget {
  final TextEditingController controller;
  const PasswordRulesList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pw = controller.text;
        const ok = Color(0xFF2E7D55);
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in passwordRules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        r.test(pw) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 17,
                        color: r.test(pw) ? ok : muted(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        r.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: r.test(pw) ? ok : muted(context),
                          fontWeight: r.test(pw) ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
