// Opens the phone's messaging app with a text prepared for residents.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/core.dart';
import '../widgets/widgets.dart';

/// Opens the phone's messaging app with every resident's mobile number and the
/// announcement already typed in. The administrator taps Send there, so the text
/// goes out from their own number and SIM (no SMS provider needed).
Future<void> textResidents(BuildContext context, String title, String body) async {
  final numbers = app.residentPhones;
  if (numbers.isEmpty) {
    msg(context, 'No resident mobile numbers on file yet. Add them under Manage access.');
    return;
  }
  final cleanBody = body.trim();
  final text = cleanBody.isEmpty || cleanBody == '—' ? title : '$title\n$cleanBody';
  final uri = Uri.parse('sms:${numbers.join(',')}?body=${Uri.encodeComponent(text)}');
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    msg(context, 'Could not open a messaging app on this device. The announcement is still published.');
  }
}
