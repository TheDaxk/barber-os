import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class ExportService {
  static Future<void> exportTo({
    required String type,
    required String unitName,
    required String monthLabel,
    required double revenue,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> orders,
    required DateTimeRange range,
    bool detailed = false,
  }) async {
    switch (type) {
      case 'pdf':
        await exportPdf(
          unitName: unitName,
          orders: orders,
          expenses: expenses,
          range: range,
          detailed: detailed,
        );
        break;
      case 'excel':
        await exportExcel(
          unitName: unitName,
          orders: orders,
          expenses: expenses,
          range: range,
        );
        break;
      case 'csv':
        await exportCsv(
          orders: orders,
          expenses: expenses,
          range: range,
        );
        break;
    }
  }

  static DateTimeRange resolvePeriod(String period, DateTimeRange? custom) {
    final now = DateTime.now();
    switch (period) {
      case '7days':
        return DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
      case '30days':
        return DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
      case 'current_month':
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case 'custom':
        return custom!;
      default:
        return DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
    }
  }

  static Future<void> exportPdf({
    required String unitName,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> expenses,
    required DateTimeRange range,
    required bool detailed,
  }) async {
    final pdf = pw.Document();

    // Carregar fontes para evitar o erro de caracteres especiais
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final logoImage = await _loadLogo();

    const gold = PdfColor.fromInt(0xFFD4AF37);
    const bgDark = PdfColor.fromInt(0xFF1A1A1A);
    const textLight = PdfColor.fromInt(0xFFFFFFFF);
    const textMuted = PdfColor.fromInt(0xFF888888);

    // Filtrar dados pelo período selecionado
    final filteredOrders = orders.where((o) {
      if (o['start_time'] == null) return false;
      final dt = DateTime.parse(o['start_time'].toString()).toLocal();
      return dt.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
             dt.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();

    final filteredExpenses = expenses.where((e) {
      if (e['expense_date'] == null) return false;
      final dt = DateTime.parse(e['expense_date'].toString()).toLocal();
      return dt.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
             dt.isBefore(range.end.add(const Duration(days: 1)));
    }).toList();

    final totalRevenue = filteredOrders.fold<double>(0, (sum, o) => sum + ((o['total'] as num?)?.toDouble() ?? 0.0));
    final totalExpenses = filteredExpenses.fold<double>(0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
    final result = totalRevenue - totalExpenses;

    final revenueByPayment = <String, double>{};
    for (final o in filteredOrders) {
      final method = o['payment_method']?.toString() ?? 'Outros';
      revenueByPayment[method] = (revenueByPayment[method] ?? 0) + ((o['total'] as num?)?.toDouble() ?? 0.0);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (ctx) => _buildPdfHeader(logoImage, unitName, range, gold, bgDark, textLight),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('BarberOS · Relatório Financeiro', style: pw.TextStyle(color: textMuted, fontSize: 8)),
              pw.Text('Pág. ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(color: textMuted, fontSize: 8)),
            ],
          ),
        ),
        build: (ctx) => [
          _pdfSectionTitle('Receitas', gold),
          pw.SizedBox(height: 8),
          _pdfRevenueTable(revenueByPayment, totalRevenue),
          if (detailed) ...[
            pw.SizedBox(height: 16),
            _pdfSectionTitle('Detalhamento de Atendimentos', gold),
            pw.SizedBox(height: 8),
            _pdfDetailedTable(filteredOrders),
          ],
          pw.SizedBox(height: 24),
          _pdfSectionTitle('Despesas', PdfColors.red300),
          pw.SizedBox(height: 8),
          _pdfExpensesTable(filteredExpenses, totalExpenses),
          pw.SizedBox(height: 24),
          _pdfSummaryBox(totalRevenue, totalExpenses, result, gold),
        ],
      ),
    );

    final bytes = await pdf.save();
    await _shareOrDownload(bytes, 'relatorio_financeiro.pdf', 'application/pdf');
  }

  static pw.Widget _buildPdfHeader(pw.ImageProvider? logo, String unitName, DateTimeRange range, PdfColor gold, PdfColor bg, PdfColor textLight) {
    String fmt(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (logo != null) pw.Image(logo, height: 32),
            pw.SizedBox(height: 6),
            pw.Text(unitName, style: pw.TextStyle(color: textLight, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('${fmt(range.start)} → ${fmt(range.end)}', style: pw.TextStyle(color: gold, fontSize: 11)),
          ]),
          pw.Text('RELATÓRIO\nFINANCEIRO', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: gold, fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _pdfSectionTitle(String title, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: color, width: 4))),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
  );

  static pw.Widget _pdfRevenueTable(Map<String, double> byPayment, double total) {
    final paymentLabels = {'pix': 'Pix', 'credit_card': 'Cartão de Crédito', 'debit_card': 'Cartão de Débito', 'cash': 'Dinheiro'};
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Forma de Pagamento', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
          ],
        ),
        ...byPayment.entries.map((e) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(paymentLabels[e.key] ?? e.key, style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('R\$ ${e.value.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
        ])),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL RECEITAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('R\$ ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _pdfDetailedTable(List<Map<String, dynamic>> orders) {
    final headers = ['Data', 'Cliente', 'Serviço', 'Produto', 'Valor', 'Barbeiro'];
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {0: const pw.FixedColumnWidth(55), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(2), 4: const pw.FixedColumnWidth(60), 5: const pw.FlexColumnWidth(2)},
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers.map((h) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)))).toList(),
        ),
        ...orders.map((o) {
          final startTime = o['start_time']?.toString();
          final dateStr = startTime != null 
              ? '${DateTime.parse(startTime).toLocal().day.toString().padLeft(2,'0')}/${DateTime.parse(startTime).toLocal().month.toString().padLeft(2,'0')}'
              : '--/--';
          return pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(o['client_name']?.toString() ?? 'Avulso', style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(o['service_name']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(o['product_name']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('R\$ ${((o['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(
              o['barbers']?['users']?['name']?.toString() ?? '-', 
              style: const pw.TextStyle(fontSize: 8)
            )),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _pdfExpensesTable(List<Map<String, dynamic>> expenses, double total) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: ['Descrição', 'Categoria', 'Valor'].map((h) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)))).toList(),
        ),
        ...expenses.map((e) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e['description']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(e['category']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('R\$ ${((e['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
        ])),
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('TOTAL DESPESAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
          pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('R\$ ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.red400), textAlign: pw.TextAlign.right)),
        ]),
      ],
    );
  }

  static pw.Widget _pdfSummaryBox(double revenue, double expenses, double result, PdfColor gold) {
    final isPositive = result >= 0;
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFF1A1A1A), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)), border: pw.Border.all(color: gold, width: 1)),
      child: pw.Column(children: [
        pw.Text('RESUMO FINANCEIRO', style: pw.TextStyle(color: gold, fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 12),
        _summaryRow('Receitas', revenue, PdfColors.green400),
        pw.SizedBox(height: 4),
        _summaryRow('Despesas', expenses, PdfColors.red400),
        pw.Divider(color: PdfColors.grey400),
        _summaryRow('Resultado', result, isPositive ? PdfColors.green400 : PdfColors.red400, bold: true),
      ]),
    );
  }

  static pw.Widget _summaryRow(String label, double value, PdfColor color, {bool bold = false}) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
    pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 11, color: PdfColors.grey100)),
    pw.Text('R\$ ${value.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 11, color: color)),
  ]);

  static Future<void> exportExcel({
    required String unitName,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> expenses,
    required DateTimeRange range,
  }) async {
    final excel = Excel.createExcel();
    final revenueSheet = excel['Receitas'];
    revenueSheet.appendRow([TextCellValue('Data'), TextCellValue('Cliente'), TextCellValue('Serviço'), TextCellValue('Produto'), TextCellValue('Forma Pagamento'), TextCellValue('Valor'), TextCellValue('Barbeiro')]);
    for (final o in orders) {
      final startTime = o['start_time']?.toString();
      if (startTime == null) continue;
      final dt = DateTime.parse(startTime).toLocal();
      
      // Filtro de data
      if (dt.isBefore(range.start.subtract(const Duration(seconds: 1))) ||
          dt.isAfter(range.end.add(const Duration(days: 1)))) continue;

      revenueSheet.appendRow([
        TextCellValue('${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'),
        TextCellValue(o['client_name']?.toString() ?? 'Avulso'),
        TextCellValue(o['service_name']?.toString() ?? '-'),
        TextCellValue(o['product_name']?.toString() ?? '-'),
        TextCellValue(o['payment_method']?.toString() ?? '-'),
        DoubleCellValue((o['total'] as num?)?.toDouble() ?? 0.0),
        TextCellValue(o['barbers']?['users']?['name']?.toString() ?? '-'),
      ]);
    }
    final expenseSheet = excel['Despesas'];
    expenseSheet.appendRow([TextCellValue('Data'), TextCellValue('Descrição'), TextCellValue('Categoria'), TextCellValue('Valor')]);
    for (final e in expenses) {
      expenseSheet.appendRow([
        TextCellValue(e['date']?.toString() ?? '-'),
        TextCellValue(e['description']?.toString() ?? '-'),
        TextCellValue(e['category']?.toString() ?? '-'),
        DoubleCellValue((e['amount'] as num).toDouble()),
      ]);
    }
    final summarySheet = excel['Resumo'];
    final revenue = orders.fold<double>(0, (s, o) => s + (o['total'] as num).toDouble());
    final exp = expenses.fold<double>(0, (s, e) => s + (e['amount'] as num).toDouble());
    summarySheet.appendRow([TextCellValue('Unidade'), TextCellValue(unitName)]);
    summarySheet.appendRow([TextCellValue('Total Receitas'), DoubleCellValue(revenue)]);
    summarySheet.appendRow([TextCellValue('Total Despesas'), DoubleCellValue(exp)]);
    summarySheet.appendRow([TextCellValue('Resultado'), DoubleCellValue(revenue - exp)]);
    excel.delete('Sheet1');
    final bytes = excel.encode()!;
    await _shareOrDownload(bytes, 'relatorio_financeiro.xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  }

  static Future<void> exportCsv({
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> expenses,
    required DateTimeRange range,
  }) async {
    final rows = <List<dynamic>>[
      ['RECEITAS'],
      ['Data', 'Cliente', 'Serviço', 'Produto', 'Pagamento', 'Valor', 'Barbeiro'],
      ...orders.where((o) {
        if (o['closed_at'] == null) return false;
        final dt = DateTime.parse(o['closed_at'].toString()).toLocal();
        return dt.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
               dt.isBefore(range.end.add(const Duration(days: 1)));
      }).map((o) {
        final dt = DateTime.parse(o['closed_at'].toString()).toLocal();
        return [
          '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}',
          o['client_name']?.toString() ?? 'Avulso',
          o['service_name']?.toString() ?? '-',
          o['product_name']?.toString() ?? '-',
          o['payment_method']?.toString() ?? '-',
          (o['total'] as num?)?.toDouble() ?? 0.0,
          o['barbers']?['users']?['name']?.toString() ?? '-',
        ];
      }),
      [],
      ['DESPESAS'],
      ['Data', 'Descrição', 'Categoria', 'Valor'],
      ...expenses.where((e) {
        if (e['expense_date'] == null) return false;
        final dt = DateTime.parse(e['expense_date'].toString()).toLocal();
        return dt.isAfter(range.start.subtract(const Duration(seconds: 1))) &&
               dt.isBefore(range.end.add(const Duration(days: 1)));
      }).map((e) => [
        e['expense_date']?.toString() ?? '-',
        e['description']?.toString() ?? '-',
        e['category']?.toString() ?? '-',
        (e['amount'] as num?)?.toDouble() ?? 0.0
      ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = csv.codeUnits;
    await _shareOrDownload(bytes, 'relatorio_financeiro.csv', 'text/csv');
  }

  static Future<void> _shareOrDownload(dynamic bytes, String filename, String mimeType) async {
    if (kIsWeb) {
      // No navegador, usamos o printing para disparar o download
      final uint8List = bytes is Uint8List ? bytes : Uint8List.fromList(bytes as List<int>);
      await Printing.sharePdf(bytes: uint8List, filename: filename);
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    if (bytes is List<int>) {
      await file.writeAsBytes(bytes);
    }
    
    if (Platform.isAndroid || Platform.isIOS) {
      await Share.shareXFiles([XFile(file.path, mimeType: mimeType)], subject: 'Relatório Financeiro — BarberOS');
    } else {
      await OpenFilex.open(file.path);
    }
  }

  static Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/icons/app_icon.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
