
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class LabsPage extends StatelessWidget {
  const LabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => app.refreshLabs(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Text('${app.labs.length} lab${app.labs.length != 1 ? 's' : ''}',
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            ),
          ),
          if (app.isLoading)
            const SliverToBoxAdapter(child: LoadingRows(count: 4))
          else if (app.labs.isEmpty)
            const SliverToBoxAdapter(child: EmptyState(message: 'No labs found', icon: Icons.science_outlined))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _LabCard(lab: app.labs[i]),
                  childCount: app.labs.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  final LabResponse lab;
  const _LabCard({required this.lab});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
            borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.science_outlined, size: 20, color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lab.name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
            const SizedBox(width: 3),
            Expanded(child: Text(lab.location, style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
          ]),
          const SizedBox(height: 2),
          Text(lab.phone, style: GoogleFonts.dmSans(fontSize: 11.5,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ])),
      ]),
    );
  }
}
