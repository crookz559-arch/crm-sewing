import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../analytics/data/analytics_repository.dart';

class ExportService {
  static final _monthNames = [
    'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
    'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'
  ];

  // ─── PDF ────────────────────────────────────────────────────────────────
  static Future<void> exportAnalyticsPdf(
      AnalyticsData data, int year) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Аналитика — $year',
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 16),

          // Summary
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _pdfMetric('Выручка', '${_fmt(data.totalRevenue)} ₽'),
              _pdfMetric('Заказов', '${data.totalOrders}'),
            ],
          ),
          pw.SizedBox(height: 20),

          // Monthly table
          pw.Text('Выручка по месяцам',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Месяц', 'Выручка (₽)', 'Заказов'],
            data: data.monthlyRevenue
                .map((m) => [
                      _monthNames[m.month - 1],
                      _fmt(m.revenue),
                      '${m.ordersCount}',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerRight,
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.indigo100),
            border: pw.TableBorder.all(color: PdfColors.grey400),
          ),
          pw.SizedBox(height: 20),

          // Top clients
          if (data.topClients.isNotEmpty) ...[
            pw.Text('Топ клиенты',
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Клиент', 'Выручка (₽)', 'Заказов'],
              data: data.topClients
                  .map((c) => [
                        c.clientName,
                        _fmt(c.revenue),
                        '${c.ordersCount}',
                      ])
                  .toList(),
              headerStyle:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerRight,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.indigo100),
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
          ],

          pw.SizedBox(height: 20),
          pw.Text(
            'Создано: ${DateTime.now().toLocal().toString().substring(0, 16)}',
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await _shareFile(
      await pdf.save(),
      'analytics_$year.pdf',
      'application/pdf',
    );
  }

  // ─── Excel ───────────────────────────────────────────────────────────────
  static Future<void> exportAnalyticsExcel(
      AnalyticsData data, int year) async {
    final excel = Excel.createExcel();

    // Monthly sheet
    final monthSheet = excel['Выручка по месяцам'];
    excel.setDefaultSheet('Выручка по месяцам');
    _excelRow(monthSheet, 0, ['Месяц', 'Выручка (₽)', 'Заказов'],
        bold: true);
    for (var i = 0; i < data.monthlyRevenue.length; i++) {
      final m = data.monthlyRevenue[i];
      _excelRow(monthSheet, i + 1,
          [_monthNames[m.month - 1], m.revenue, m.ordersCount]);
    }

    // Clients sheet
    if (data.topClients.isNotEmpty) {
      final clientSheet = excel['Топ клиенты'];
      _excelRow(clientSheet, 0, ['Клиент', 'Выручка (₽)', 'Заказов'],
          bold: true);
      for (var i = 0; i < data.topClients.length; i++) {
        final c = data.topClients[i];
        _excelRow(
            clientSheet, i + 1, [c.clientName, c.revenue, c.ordersCount]);
      }
    }

    // Status sheet
    if (data.statusStats.isNotEmpty) {
      final statusSheet = excel['Статусы'];
      _excelRow(statusSheet, 0, ['Статус', 'Кол-во'], bold: true);
      for (var i = 0; i < data.statusStats.length; i++) {
        final s = data.statusStats[i];
        _excelRow(statusSheet, i + 1, [s.status, s.count]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encode failed');
    await _shareFile(
        Uint8List.fromList(bytes),
        'analytics_$year.xlsx',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  // ─── Orders export ────────────────────────────────────────────────────
  static Future<void> exportOrdersExcel(
      List<Map<String, dynamic>> orders, String filename) async {
    final excel = Excel.createExcel();
    final sheet = excel['Заказы'];
    excel.setDefaultSheet('Заказы');

    _excelRow(sheet, 0,
        ['ID', 'Название', 'Клиент', 'Статус', 'Срок', 'Цена', 'Создан'],
        bold: true);

    for (var i = 0; i < orders.length; i++) {
      final o = orders[i];
      _excelRow(sheet, i + 1, [
        (o['id'] as String?)?.substring(0, 8) ?? '',
        o['title'] ?? '',
        (o['clients'] as Map?)?['name'] ?? '',
        o['status'] ?? '',
        o['deadline'] ?? '',
        o['price'] ?? '',
        (o['created_at'] as String?)?.substring(0, 10) ?? '',
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel encode failed');
    await _shareFile(
        Uint8List.fromList(bytes),
        filename,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  static pw.Widget _pdfMetric(String label, String value) {
    return pw.Column(children: [
      pw.Text(value,
          style:
              pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text(label,
          style: const pw.TextStyle(
              fontSize: 11, color: PdfColors.grey700)),
    ]);
  }

  static void _excelRow(Sheet sheet, int row, List<dynamic> values,
      {bool bold = false}) {
    for (var col = 0; col < values.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
      final v = values[col];
      if (v is int) {
        cell.value = IntCellValue(v);
      } else if (v is double) {
        cell.value = DoubleCellValue(v);
      } else {
        cell.value = TextCellValue(v?.toString() ?? '');
      }
      if (bold) {
        cell.cellStyle = CellStyle(bold: true);
      }
    }
  }

  static Future<void> _shareFile(
      Uint8List bytes, String filename, String mimeType) async {
    // XFile.fromData works on all platforms (web, iOS, Android).
    // share_plus manages any required temp file internally, so we don't
    // need to write or delete our own temp file — which eliminates the
    // iOS race where file.delete() ran before the Share Sheet finished reading.
    final xFile = XFile.fromData(bytes, name: filename, mimeType: mimeType);
    await Share.shareXFiles([xFile], subject: filename);
  }

  static String _fmt(double v) {
    return v.toStringAsFixed(0);
  }
}
