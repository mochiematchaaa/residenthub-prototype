// The choice 'send the code by email or text message'.

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'common.dart';

/// "How should we send the code?" Only the ways that are set up are offered
/// (text message and/or email). [value] is 'sms' or 'email'.
class ChannelPicker extends StatelessWidget {
  final bool smsReady, emailReady;
  final String value, phone, email;
  final ValueChanged<String> onChanged;

  const ChannelPicker({
    super.key,
    required this.smsReady,
    required this.emailReady,
    required this.value,
    required this.onChanged,
    this.phone = '',
    this.email = '',
  });

  Widget _tile(BuildContext context, String v, IconData icon, String title, String sub) {
    final on = value == v;
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(v),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? color : Colors.black12, width: on ? 2 : 1.2),
            color: on ? color.withOpacity(0.08) : null,
          ),
          child: Row(
            children: [
              Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? color : Colors.black38),
              const SizedBox(width: 12),
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(sub, style: TextStyle(color: muted(context), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (smsReady)
          _tile(context, 'sms', Icons.sms_outlined, 'Text message (SMS)', phone.isEmpty ? 'to your mobile number' : 'to $phone'),
        if (emailReady)
          _tile(context, 'email', Icons.mail_outline_rounded, 'Email (Gmail)', email.isEmpty ? 'to your email address' : 'to $email'),
      ],
    );
  }
}
