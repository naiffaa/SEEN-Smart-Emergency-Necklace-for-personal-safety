import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/theme/colors.dart';
import '../../../main.dart';

class AdminReportDetailsPage extends StatelessWidget {
  final String title;
  final String description;
  final int totalAlerts;
  final int resolvedAlerts;
  final int pendingAlerts;

  const AdminReportDetailsPage({
    super.key,
    required this.title,
    required this.description,
    required this.totalAlerts,
    required this.resolvedAlerts,
    required this.pendingAlerts,
  });

  Future<void> _exportPdf(BuildContext context) async {
    final lang = appLanguage;
    final now = DateTime.now();
    final dateStr =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(description, style: const pw.TextStyle(fontSize: 13)),
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfMetric(
                    lang.text(en: "Total Alerts", ar: "إجمالي التنبيهات"),
                    totalAlerts.toString(),
                  ),
                  _pdfMetric(
                    lang.text(en: "Resolved", ar: "تم الحل"),
                    resolvedAlerts.toString(),
                  ),
                  _pdfMetric(
                    lang.text(en: "Pending", ar: "معلّق"),
                    pendingAlerts.toString(),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 16),
              pw.Text(
                lang.text(
                  en: "Generated: $dateStr",
                  ar: "تاريخ الإنشاء: $dateStr",
                ),
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '$title - $dateStr',
    );
  }

  pw.Widget _pdfMetric(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = appLanguage;
    final now = DateTime.now();

    final String generatedDate =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    final double maxY =
        [
          totalAlerts.toDouble(),
          resolvedAlerts.toDouble(),
          pendingAlerts.toDouble(),
          5,
        ].reduce((a, b) => a > b ? a : b) +
        2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    label: lang.text(
                      en: "Total Alerts",
                      ar: "إجمالي التنبيهات",
                    ),
                    value: totalAlerts.toString(),
                    color: AppColors.textPrimary,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    label: lang.text(en: "Resolved", ar: "تم الحل"),
                    value: resolvedAlerts.toString(),
                    color: AppColors.success,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _metricCard(
                    label: lang.text(en: "Pending", ar: "قيد الانتظار"),
                    value: pendingAlerts.toString(),
                    color: AppColors.emergencyRed,
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.text(
                      en: "Alert Trend Overview",
                      ar: "نظرة عامة على اتجاه التنبيهات",
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                switch (value.toInt()) {
                                  case 0:
                                    return Text(
                                      lang.text(en: "Total", ar: "الإجمالي"),
                                      style: const TextStyle(fontSize: 11),
                                    );
                                  case 1:
                                    return Text(
                                      lang.text(en: "Resolved", ar: "تم الحل"),
                                      style: const TextStyle(fontSize: 11),
                                    );
                                  case 2:
                                    return Text(
                                      lang.text(en: "Pending", ar: "معلق"),
                                      style: const TextStyle(fontSize: 11),
                                    );
                                  default:
                                    return const Text("");
                                }
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) =>
                              FlLine(color: Colors.black12, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: totalAlerts.toDouble(),
                                color: AppColors.primary,
                                width: 35,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: resolvedAlerts.toDouble(),
                                color: AppColors.success,
                                width: 35,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 2,
                            barRods: [
                              BarChartRodData(
                                toY: pendingAlerts.toDouble(),
                                color: AppColors.emergencyRed,
                                width: 35,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(
                        AppColors.primary,
                        lang.text(en: "Total", ar: "الإجمالي"),
                      ),
                      const SizedBox(width: 16),
                      _legendDot(
                        AppColors.success,
                        lang.text(en: "Resolved", ar: "تم الحل"),
                      ),
                      const SizedBox(width: 16),
                      _legendDot(
                        AppColors.emergencyRed,
                        lang.text(en: "Pending", ar: "معلق"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _exportPdf(context),
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                label: Text(
                  lang.text(
                    en: "Export Report (PDF)",
                    ar: "تصدير التقرير (PDF)",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              lang.text(
                en: "Generated: $generatedDate",
                ar: "تاريخ الإنشاء: $generatedDate",
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
