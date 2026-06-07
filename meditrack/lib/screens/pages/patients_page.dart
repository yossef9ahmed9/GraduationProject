import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});
  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<PatientResponse> _filtered(List<PatientResponse> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((p) =>
    p.name.toLowerCase().contains(q) ||
        p.email.toLowerCase().contains(q) ||
        p.phone.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;
    final canChat = role == UserRole.doctor ||
        role == UserRole.admin  ||
        role == UserRole.lab;
    final filtered = _filtered(app.patients);

    return RefreshIndicator(
      onRefresh: () => app.refreshPatients(role),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, email or phone…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      })
                      : null,
                ),
              ),
            ),
          ),
          // Count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '${filtered.length} patient${filtered.length != 1 ? 's' : ''}',
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
          ),
          // List
          if (app.isLoading)
            const SliverToBoxAdapter(child: LoadingRows(count: 6))
          else if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                message: _query.isNotEmpty ? 'No patients match your search' : 'No patients found',
                icon: Icons.people_outline,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, i) => _PatientCard(
                    patient: filtered[i],
                    canChat: canChat,
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final PatientResponse patient;
  final bool canChat;
  const _PatientCard({required this.patient, required this.canChat});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        AvatarWidget(initials: patient.initials, size: 40, fontSize: 14),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient.name,
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(patient.email,
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            if (patient.phone.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(patient.phone,
                  style: GoogleFonts.dmSans(fontSize: 11.5,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
            ],
            if (patient.isInEmergency) ...[
              const SizedBox(height: 4),
              BadgeWidget(label: 'EMERGENCY', type: BadgeType.red),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          BadgeWidget(
            label: patient.gender.isNotEmpty
                ? patient.gender[0].toUpperCase() + patient.gender.substring(1)
                : '—',
            type: patient.gender.toLowerCase() == 'female'
                ? BadgeType.blue : BadgeType.green,
          ),
          // Chat button — doctor/admin/lab can chat with patient
          if (canChat && patient.email.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherEmail: patient.email,
                  otherName:  patient.name,
                ),
              )),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
              label: Text('Chat',
                  style: GoogleFonts.dmSans(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}