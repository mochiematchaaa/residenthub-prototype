// Language support. L('English', 'Filipino') picks the text for the language chosen in Settings,
// and tr('English text') translates menu labels and page titles (unknown text stays as it is).

import 'app_state.dart';

const kLanguages = <({String code, String name, String native, String sample})>[
  (code: 'en', name: 'English', native: 'English', sample: 'Good morning, welcome back'),
  (code: 'fil', name: 'Filipino', native: 'Taglish: English at Tagalog', sample: 'Magandang umaga, welcome back'),
];

bool get isFil => app.lang == 'fil';

/// The English or the Filipino text, depending on the language chosen in Settings.
String L(String en, String fil) => isFil ? fil : en;

/// Translates a menu label or title when the language is Filipino.
String tr(String s) => isFil ? (_fil[s] ?? s) : s;

const _fil = <String, String>{
  // tabs and menus (Taglish: everyday English app words with Tagalog connectors)
  'Home': 'Home', 'Units': 'Mga Unit', 'Facility': 'Facility', 'Finance': 'Finance', 'More': 'Iba pa',
  'Book': 'Mag-book', 'Parking': 'Parking', 'Dues': 'Mga Bayarin',
  'Settings': 'Settings', 'Calendar': 'Calendar', 'Complaints': 'Mga Reklamo', 'Maintenance': 'Maintenance',
  'My unit': 'Unit Ko', 'Community': 'Community', 'Account': 'Account', 'Operations': 'Operations', 'Administration': 'Administration',
  'Money and files': 'Pera at Files', 'Documents': 'Mga Dokumento',
  'My reservations': 'Mga Reservation Ko', 'Motor parking': 'Parking ng Motor', 'Community documents': 'Mga Dokumento ng Community',
  'Announcements & events': 'Mga Announcement at Event', 'Directory & house rules': 'Directory at House Rules',
  'Directory and house rules': 'Directory at House Rules', 'Activity log': 'Activity Log', 'Expenses': 'Mga Gastos',
  'Finance documents': 'Mga Finance Document', 'Reports': 'Mga Report', 'Resident profiles': 'Profile ng mga Resident',
  'Unit status': 'Status ng Unit', 'Polls': 'Mga Poll',
  'Events and facility bookings': 'Mga Event at Facility Booking',
  'Events, bookings and due dates': 'Mga event, booking at due date',
  'Contacts, rules and common questions': 'Mga contact, house rules at madalas itanong',
  'Collections, units, concerns, bookings': 'Collections, units, reklamo, bookings',
  'Statement, payments and receipts': 'Statement, bayad at resibo',
  'Profile, password, devices, language': 'Profile, password, devices, language',
  'Account and security, access, payments': 'Account at security, access, payments',
  'Your account and security, who can sign in, and payments.': 'Ang account at security mo, sino ang puwedeng mag-sign in, at mga payment.',
  'Everything else for your unit.': 'Lahat ng iba pa para sa unit mo.',
  // sections
  'Overview': 'Overview', 'Quick access': 'Quick access', 'Good morning': 'Magandang umaga',
  'Good afternoon': 'Magandang hapon', 'Good evening': 'Magandang gabi',
};
