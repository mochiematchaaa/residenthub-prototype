// Opens the phone's messaging app with a text prepared for residents.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/core.dart';
import 'demo.dart';
import '../widgets/widgets.dart';

/// Opens the phone's messaging app with every resident's mobile number and the
/// announcement already typed in. The administrator taps Send there, so the text
/// goes out from their own number and SIM (no SMS provider needed).
Future<void> textResidents(BuildContext context, String title, String body) => textNumbers(context, app.residentPhones, title, body);

/// Same, for a chosen list of mobile numbers (09XXXXXXXXX form).
Future<void> textNumbers(BuildContext context, List<String> numbers, String title, String body) async {
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
    msg(context, kDemo
        ? 'Text message prepared for ${numbers.length} number${numbers.length == 1 ? '' : 's'}. The prototype does not send real texts; on a phone the app opens the messaging app with these numbers.'
        : 'Could not open a messaging app on this device. The announcement is still published.');
  }
}

/// Opens the phone dialer for one number (the administrator taps Call there).
Future<void> callNumber(BuildContext context, String number) async {
  final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse('tel:$digits'), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    msg(context, kDemo ? 'Calling $number. The prototype cannot place real calls; on a phone the dialer opens with this number.' : 'Could not open the phone dialer on this device.');
  }
}

/// Opens the messaging app with a text for one number already typed in.
Future<void> textOne(BuildContext context, String number, String text) async {
  final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse('sms:$digits?body=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    msg(context, kDemo ? 'Text message prepared for $number. The prototype does not send real texts; on a phone the app opens the messaging app.' : 'Could not open a messaging app on this device.');
  }
}
