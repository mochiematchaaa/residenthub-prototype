// Opens the public website from the app.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/widgets.dart';

/// The ResidentHub public website (it also shows this app inside a phone frame).
/// Change the address here if the website moves.
const String kWebsiteUrl = 'https://mochiematchaaa.github.io/';

/// Opens the website in the browser (a new tab on the web version).
Future<void> openWebsite(BuildContext context) async {
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(kWebsiteUrl), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    msg(context, 'Could not open the website. Visit $kWebsiteUrl in your browser.');
  }
}
