// Language support. L('English', 'Filipino') picks the text for the language chosen in Settings,
// and tr('English text') translates menu labels and page titles (unknown text stays as it is).

import 'app_state.dart';

const kLanguages = <({String code, String name, String native, String sample})>[
  (code: 'en', name: 'English', native: 'English', sample: 'Good morning, welcome back'),
  (code: 'fil', name: 'Filipino', native: 'Wikang Filipino', sample: 'Magandang umaga, maligayang pagbabalik'),
];

bool get isFil => app.lang == 'fil';

/// The English or the Filipino text, depending on the language chosen in Settings.
String L(String en, String fil) => isFil ? fil : en;

/// Translates a menu label or title when the language is Filipino.
String tr(String s) => isFil ? (_fil[s] ?? s) : s;

const _fil = <String, String>{
  // tabs and menus
  'Home': 'Home', 'Units': 'Mga unit', 'Facility': 'Pasilidad', 'Finance': 'Pananalapi', 'More': 'Higit pa',
  'Book': 'Mag-book', 'Parking': 'Paradahan', 'Dues': 'Mga bayarin',
  'Settings': 'Mga setting', 'Calendar': 'Kalendaryo', 'Complaints': 'Mga reklamo', 'Maintenance': 'Pagpapanatili',
  'My unit': 'Aking unit', 'Community': 'Komunidad', 'Account': 'Account', 'Operations': 'Operasyon', 'Administration': 'Pangangasiwa',
  'Money and files': 'Pera at mga file', 'Documents': 'Mga dokumento',
  'My reservations': 'Aking mga reserbasyon', 'Motor parking': 'Paradahan ng motor', 'Community documents': 'Mga dokumento ng komunidad',
  'Announcements & events': 'Mga anunsyo at kaganapan', 'Directory & house rules': 'Direktoryo at mga patakaran',
  'Directory and house rules': 'Direktoryo at mga patakaran', 'Activity log': 'Talaan ng gawain', 'Expenses': 'Mga gastos',
  'Finance documents': 'Mga dokumento sa pananalapi', 'Reports': 'Mga ulat', 'Resident profiles': 'Profile ng mga residente',
  'Unit status': 'Katayuan ng unit', 'Polls': 'Mga botohan',
  'Events and facility bookings': 'Mga kaganapan at pag-book ng pasilidad',
  'Events, bookings and due dates': 'Mga kaganapan, booking at takdang petsa',
  'Contacts, rules and common questions': 'Mga contact, patakaran at karaniwang tanong',
  'Collections, units, concerns, bookings': 'Koleksyon, unit, hinaing, booking',
  'Statement, payments and receipts': 'Statement, bayad at resibo',
  'Profile, password, devices, language': 'Profile, password, device, wika',
  'Account and security, access, payments': 'Account at seguridad, access, bayad',
  'Your account and security, who can sign in, and payments.': 'Ang iyong account at seguridad, sino ang makakapag-sign in, at mga bayad.',
  'Everything else for your unit.': 'Lahat ng iba pa para sa iyong unit.',
  // sections
  'Overview': 'Pangkalahatang-tanaw', 'Quick access': 'Mabilis na access', 'Good morning': 'Magandang umaga',
  'Good afternoon': 'Magandang hapon', 'Good evening': 'Magandang gabi',
};
