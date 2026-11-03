// Opens the phone's dialer with a resident's number.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'demo.dart';
import '../widgets/widgets.dart';

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
