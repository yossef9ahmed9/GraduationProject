
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => app.refreshSensors(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Text('${app.sensors.length} sensor${app.sensors.length != 1 ? 's' : ''}',
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            ),
          ),
          if (app.isLoading)
            const SliverToBoxAdapter(child: LoadingRows(count: 4))
          else if (app.sensors.isEmpty)
            const SliverToBoxAdapter(child: EmptyState(message: 'No sensors found', icon: Icons.sensors_outlined))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _SensorCard(sensor: app.sensors[i], app: app),
                  childCount: app.sensors.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final SensorResponse sensor;
  final AppProvider app;
  const _SensorCard({required this.sensor, required this.app});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final patName = app.patientName(sensor.patientId) ?? 'Patient #${sensor.patientId}';
    final lastPing = sensor.lastPing != null
        ? DateTime.tryParse(sensor.lastPing!)?.toLocal().toString().split('.').first ?? '—'
        : 'Never';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: sensor.isActive
                ? (isDark ? AppColors.darkBadgeGreenBg : AppColors.badgeGreenBg)
                : (isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.sensors_outlined, size: 20,
            color: sensor.isActive
                ? (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)
                : (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${sensor.type} — #${sensor.id}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(patName, style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text('Last ping: $lastPing', style: GoogleFonts.dmSans(fontSize: 11.5,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ])),
        BadgeWidget(
          label: sensor.isActive ? 'Active' : 'Offline',
          type: sensor.isActive ? BadgeType.green : BadgeType.red),
      ]),
    );
  }
}
