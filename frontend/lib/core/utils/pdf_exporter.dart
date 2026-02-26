import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Converts a Markdown string to a styled PDF and triggers a browser download.
/// [fileName] should not include the .pdf extension.
Future<void> exportMarkdownToPdf({
  required String markdownContent,
  required String fileName,
}) async {
  final pdf = pw.Document();

  // Load a font that supports the full Latin character set
  final ttf = await PdfGoogleFonts.interRegular();
  final ttfBold = await PdfGoogleFonts.interBold();
  final ttfItalic = await PdfGoogleFonts.interItalic();

  final lines = markdownContent.split('\n');
  final widgets = <pw.Widget>[];

  for (final raw in lines) {
    final line = raw.trimRight();

    if (line.startsWith('# ')) {
      // H1
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Text(
        line.substring(2).trim(),
        style: pw.TextStyle(
          font: ttfBold,
          fontSize: 20,
          color: PdfColor.fromHex('#2563EB'),
        ),
      ));
      widgets.add(pw.Divider(color: PdfColor.fromHex('#2563EB'), thickness: 1.5));
      widgets.add(pw.SizedBox(height: 4));
    } else if (line.startsWith('## ')) {
      // H2
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(pw.Text(
        line.substring(3).trim(),
        style: pw.TextStyle(
          font: ttfBold,
          fontSize: 15,
          color: PdfColor.fromHex('#1E40AF'),
        ),
      ));
      widgets.add(pw.Divider(
          color: PdfColor.fromHex('#E2E8F0'), thickness: 0.5));
      widgets.add(pw.SizedBox(height: 2));
    } else if (line.startsWith('### ')) {
      // H3
      widgets.add(pw.SizedBox(height: 6));
      widgets.add(pw.Text(
        line.substring(4).trim(),
        style: pw.TextStyle(
          font: ttfBold,
          fontSize: 13,
          color: PdfColor.fromHex('#374151'),
        ),
      ));
      widgets.add(pw.SizedBox(height: 2));
    } else if (line.startsWith('#### ')) {
      // H4
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Text(
        line.substring(5).trim(),
        style: pw.TextStyle(
          font: ttfBold,
          fontSize: 12,
          color: PdfColor.fromHex('#374151'),
        ),
      ));
    } else if (line.startsWith('---') || line.startsWith('━━━')) {
      // Horizontal rule
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Divider(
          color: PdfColor.fromHex('#E2E8F0'), thickness: 0.8));
      widgets.add(pw.SizedBox(height: 4));
    } else if (RegExp(r'^[-*]\s').hasMatch(line)) {
      // Unordered list item
      final text = line.replaceFirst(RegExp(r'^[-*]\s'), '').trim();
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('•  ',
                  style: pw.TextStyle(font: ttfBold, fontSize: 11)),
              pw.Expanded(
                  child: pw.Text(_stripInlineMarkdown(text),
                      style: pw.TextStyle(font: ttf, fontSize: 11, lineSpacing: 2))),
            ],
          ),
        ),
      );
    } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
      // Ordered list item
      final match = RegExp(r'^(\d+)\.\s(.*)').firstMatch(line);
      if (match != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${match.group(1)}.  ',
                    style: pw.TextStyle(font: ttfBold, fontSize: 11)),
                pw.Expanded(
                    child: pw.Text(_stripInlineMarkdown(match.group(2)!.trim()),
                        style: pw.TextStyle(font: ttf, fontSize: 11, lineSpacing: 2))),
              ],
            ),
          ),
        );
      }
    } else if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
      // Bold-only line (section labels like **Section A: …**)
      final inner = line.replaceAll(RegExp(r'^\*\*|\*\*$'), '').trim();
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Text(inner,
          style: pw.TextStyle(font: ttfBold, fontSize: 12)));
    } else if (line.isEmpty) {
      widgets.add(pw.SizedBox(height: 5));
    } else {
      // Regular paragraph / inline content
      final cleaned = _stripInlineMarkdown(line);
      if (cleaned.isNotEmpty) {
        widgets.add(pw.Text(
          cleaned,
          style: pw.TextStyle(
              font: ttf,
              fontSize: 11,
              lineSpacing: 2,
              color: PdfColor.fromHex('#1F2937')),
        ));
        widgets.add(pw.SizedBox(height: 2));
      }
    }
  }

  // Page footer
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
      header: (_) => pw.SizedBox.shrink(),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by AI Schools',
              style: pw.TextStyle(
                  font: ttfItalic,
                  fontSize: 9,
                  color: PdfColor.fromHex('#9CA3AF'))),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(
                  font: ttf,
                  fontSize: 9,
                  color: PdfColor.fromHex('#9CA3AF'))),
        ],
      ),
      build: (_) => widgets,
    ),
  );

  // Triggers browser download on web; print dialog on native
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: '$fileName.pdf',
  );
}

/// Removes inline markdown syntax (bold, italic, backticks, links).
String _stripInlineMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')  // **bold**
      .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')        // *italic*
      .replaceAll(RegExp(r'`(.*?)`'), r'$1')          // `code`
      .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1') // [link](url)
      .replaceAll(RegExp(r'_Answer:_'), 'Answer:')
      .replaceAll('&nbsp;', ' ')
      .trim();
}
