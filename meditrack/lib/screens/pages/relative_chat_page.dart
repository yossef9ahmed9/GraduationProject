import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';

// ════════════════════════════════════════════════════════════════
// RelativeChatPage
// Shows the relative a list of doctors (via follow-ups) and labs
// (via lab appointments) linked to their patient.
// They can tap any contact to open a chat.
// ════════════════════════════════════════════════════════════════
class RelativeChatPage extends StatelessWidget {
  const RelativeChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Linked patient (relative has exactly one)
    final patient = app.patients.isNotEmpty ? app.patients.first : null;

    if (patient == null) {
      return const EmptyState(
        message: 'Link to a patient first to chat with their care team.',
        icon: Icons.chat_bubble_outline_rounded,
      );
    }

    // Doctors via follow-ups for this patient
    final doctorIds = app.followUps
        .where((f) => f.patientId == patient.id)
        .map((f) => f.doctorId)
        .toSet();
    final doctors = app.doctors
        .where((d) => doctorIds.contains(d.id))
        .toList();

    // Labs via appointments for this patient
    final labIds = app.labAppointments
        .where((a) => a.patientId == patient.id)
        .map((a) => a.labId)
        .toSet();
    final labs = app.labs
        .where((l) => labIds.contains(l.id))
        .toList();

    final hasContacts = doctors.isNotEmpty || labs.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          app.refreshDoctors(),
          app.refreshLabs(),
          app.refreshFollowUps(UserRole.relative, ''),
          app.refreshLabAppointments(),
        ]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Care Team',
                    style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Chat with ${patient.name}\'s doctors and labs.',
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary)),
              ]),
            ),
          ),
          if (!hasContacts)
            const SliverToBoxAdapter(
              child: EmptyState(
                message: 'No care team members yet.\nWait for the patient to book or follow up.',
                icon: Icons.people_outline,
              ),
            )
          else ...[
            // Doctors section
            if (doctors.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SectionHeader(label: 'Doctors'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ContactTile(
                      name:   doctors[i].name,
                      sub:    doctors[i].specialization,
                      icon:   Icons.medical_services_outlined,
                      iconBg: isDark
                          ? AppColors.darkBadgeBlueBg
                          : AppColors.badgeBlueBg,
                      iconFg: isDark
                          ? AppColors.darkBadgeBlueTxt
                          : AppColors.badgeBlueTxt,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ChatScreen(
                          otherEmail: doctors[i].email,
                          otherName:  doctors[i].name,
                        )),
                      ),
                    ),
                    childCount: doctors.length,
                  ),
                ),
              ),
            ],

            // Labs section
            if (labs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: SectionHeader(label: 'Labs'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _ContactTile(
                      name:   labs[i].name,
                      sub:    labs[i].location,
                      icon:   Icons.science_outlined,
                      iconBg: isDark
                          ? AppColors.darkBadgeGreenBg
                          : AppColors.badgeGreenBg,
                      iconFg: isDark
                          ? AppColors.darkBadgeGreenTxt
                          : AppColors.badgeGreenTxt,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ChatScreen(
                          otherEmail: labs[i].email,
                          otherName:  labs[i].name,
                        )),
                      ),
                    ),
                    childCount: labs.length,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String     name, sub;
  final IconData   icon;
  final Color      iconBg, iconFg;
  final VoidCallback onTap;

  const _ContactTile({
    required this.name, required this.sub,
    required this.icon, required this.iconBg, required this.iconFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary)),
          ])),
          Icon(Icons.chat_bubble_outline_rounded, size: 18,
              color: isDark ? AppColors.darkAccent : AppColors.accent),
        ]),
      ),
    );
  }
}
