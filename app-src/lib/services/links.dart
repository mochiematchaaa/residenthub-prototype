// Opens the public website from the app.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/widgets.dart';
import 'demo.dart' show kPrototype;

/// The ResidentHub public website (it also shows this app inside a phone frame).
/// Change the address here if the website moves.
const String kWebsiteUrl = 'https://mochiematchaaa.github.io/';

/// The website to open. The prototype web build lives in the /app/ folder of the prototype website,
/// so its website is the folder above it; everything else uses [kWebsiteUrl].
String websiteUrl() {
  if (kIsWeb && kPrototype) {
    final u = Uri.base;
    final i = u.path.lastIndexOf('/app/');
    if (i >= 0) return '${u.origin}${u.path.substring(0, i + 1)}';
  }
  return kWebsiteUrl;
}

/// Opens the website in the browser (a new tab on the web version).
Future<void> openWebsite(BuildContext context) async {
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(websiteUrl()), mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    msg(context, 'Could not open the website. Visit ${websiteUrl()} in your browser.');
  }
}
