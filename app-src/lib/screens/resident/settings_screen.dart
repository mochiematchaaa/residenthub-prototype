// RESIDENT page: Settings. Profile, password, devices and language live in Account & security.

import 'package:flutter/material.dart';

import '../shared/account_security.dart';

class ResSettings extends StatelessWidget {
  const ResSettings({super.key});

  @override
  Widget build(BuildContext context) => const AccountSecurityScreen(admin: false);
}
