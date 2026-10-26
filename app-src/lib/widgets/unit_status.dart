// The usage options (owner, tenant, short-term, business...) and their look.

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'common.dart';

/// Look and wording for each unit state (shared by resident and admin screens).
class StatusOption {
  final String key;
  final String label;
  final String hint; // what the resident can write in the note field
  final String help; // one-line explanation on the picker tile
  final IconData icon;
  final Pastel color;
  final Tone tone;
  const StatusOption(this.key, this.label, this.help, this.hint, this.icon, this.color, this.tone);

  /// One-word version for big tiles.
  String get shortLabel => switch (key) {
        'owner' => 'Occupied',
        'tenant' => 'Rented',
        'shortterm' => 'Short-term',
        'business' => 'Business',
        'away' => 'Away',
        'renovation' => 'Renovating',
        _ => 'Vacant',
      };
}

const statusOptions = <StatusOption>[
  StatusOption('owner', 'Owner-occupied', 'I live here myself.', 'Optional note', Icons.home_rounded, Pastel.mint, Tone.good),
  StatusOption('tenant', 'Rented out', 'Leased to a tenant long-term.', 'Tenant name and contact', Icons.key_rounded, Pastel.sky, Tone.info),
  StatusOption('shortterm', 'Short-term rental', 'Airbnb, Booking.com, etc.', 'Platform used, e.g. Airbnb', Icons.hotel_rounded, Pastel.peach, Tone.warn),
  StatusOption('business', 'Home business', 'Office or business use.', 'Type of business', Icons.business_center_rounded, Pastel.butter, Tone.warn),
  StatusOption('away', 'Owner away', 'Nobody is staying for now.', 'Optional: when you will be back', Icons.flight_takeoff_rounded, Pastel.lavender, Tone.info),
  StatusOption('renovation', 'Under renovation', 'Repairs or works in progress.', 'What works and until when', Icons.construction_rounded, Pastel.coral, Tone.warn),
  StatusOption('vacant', 'Vacant', 'Empty and available.', 'Optional note', Icons.meeting_room_outlined, Pastel.pink, Tone.bad),
];

StatusOption statusOf(String key) =>
    statusOptions.firstWhere((o) => o.key == key, orElse: () => statusOptions.first);
