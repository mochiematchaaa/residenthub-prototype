import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:residenthub_dashboard/core/core.dart';
import 'package:residenthub_dashboard/services/demo.dart';
import 'package:residenthub_dashboard/services/unit_history_export.dart';
import 'package:residenthub_dashboard/services/xlsx_rich.dart';

void main() {
  test('writes sample workbooks for checking', () {
    Directory('build/samples').createSync(recursive: true);
    final plain = buildXlsxRich([
      RSheet('Test', 'Banner', [
        RTable('Numbers', const ['Month', 'A', 'B'], [
          ['Jan', 10, 20],
          ['Feb', 30, 5],
        ], kinds: const ['text', 'money', 'money'], chart: const RChart('Chart', valueCols: [1, 2])),
      ]),
    ]);
    File('build/samples/rich.xlsx').writeAsBytesSync(plain);
    expect(plain.length, greaterThan(1000));

    startDemo(Role.admin);
    final unit = app.units.first.unit;
    final bytes = buildUnitHistoryXlsx(unit)!;
    File('build/samples/unit_history.xlsx').writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(2000));
    app.autoPostCheck();
  });
}
