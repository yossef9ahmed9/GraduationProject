import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/chat_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';
import 'package:meditrack/screens/user_profile_screen.dart';
import 'package:meditrack/screens/ambulance_tracking_screen.dart';

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});
  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Set<String> _chatContactEmails = {};
  bool _contactsLoaded = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) {
        context.read<AppProvider>().refreshPatients(context.read<AuthProvider>().role);
      }
    });
  }

  Future<void> _loadContacts() async {
    final auth = context.read<AuthProvider>();
    if (auth.role != UserRole.lab) { setState(() => _contactsLoaded = true); return; }
    final convs = await chatService.getConversations();
    if (!mounted) return;
    setState(() {
      _chatContactEmails = convs.map((c) => c.otherEmail.toLowerCase()).toSet();
      _contactsLoaded    = true;
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Returns patients visible to the current role:
  /// - Doctor  → only patients linked via follow-ups (already filtered by backend)
  /// - Lab     → only patients who booked an appointment with this lab
  ///             OR have sent a chat message to this lab
  /// - Others  → all patients
  List<PatientResponse> _visiblePatients(
      AppProvider app, UserRole role, String myEmail) {
    if (role == UserRole.lab) {
      // IDs from lab appointments
      final apptPatientIds = app.labAppointments
          .where((a) => a.labId ==
              app.labs
                  .where((l) => l.email.toLowerCase() == myEmail.toLowerCase())
                  .map((l) => l.id)
                  .firstOrNull)
          .map((a) => a.patientId)
          .toSet();
      return app.patients.where((p) {
        final bookedHere    = apptPatientIds.contains(p.id);
        final chattedWithMe = _chatContactEmails.contains(p.email.toLowerCase());
        return bookedHere || chattedWithMe;
      }).toList();
    }
    // Doctor already receives only their patients from backend (getDoctorPatients)
    return app.patients;
  }

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
    final myEmail = auth.user?.email ?? '';
    final canChat = role == UserRole.doctor ||
        role == UserRole.admin  ||
        role == UserRole.lab;

    final visible  = _contactsLoaded
        ? _visiblePatients(app, role, myEmail)
        : <PatientResponse>[];
    final filtered = _filtered(visible);

    return RefreshIndicator(
      onRefresh: () async {
        await app.refreshPatients(role);
        await _loadContacts();
      },
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
                    patient:       filtered[i],
                    canChat:       canChat,
                    activeDispatch: app.dispatches
                        .where((d) =>
                            d.patientId == filtered[i].id && d.isActive)
                        .firstOrNull,
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
  final EmergencyDispatchResponse? activeDispatch;
  const _PatientCard({
    required this.patient,
    required this.canChat,
    this.activeDispatch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: avatar + info + gender badge
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AvatarWidget(
              initials: patient.initials, size: 40, fontSize: 14,
              photoUrl: patient.profilePictureUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(patient.name,
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(patient.email,
                  style: GoogleFonts.dmSans(fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
              if (patient.phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(patient.phone,
                    style: GoogleFonts.dmSans(fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary)),
              ],
              if (patient.isInEmergency) ...[
                const SizedBox(height: 4),
                BadgeWidget(label: 'EMERGENCY', type: BadgeType.red),
              ],
            ]),
          ),
          BadgeWidget(
            label: patient.gender.isNotEmpty
                ? patient.gender[0].toUpperCase() + patient.gender.substring(1)
                : '—',
            type: patient.gender.toLowerCase() == 'female'
                ? BadgeType.blue : BadgeType.green,
          ),
        ]),

        // Bottom row: Profile + Chat + Track buttons (full width)
        if (canChat && patient.email.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserProfileScreen.patient(patient),
                )),
                icon: const Icon(Icons.person_outline, size: 14),
                label: Text('Profile', style: GoogleFonts.dmSans(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    otherEmail: patient.email,
                    otherName:  patient.name,
                  ),
                )),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                label: Text('Chat', style: GoogleFonts.dmSans(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (activeDispatch != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AmbulanceTrackingScreen(
                      patientId:   patient.id,
                      patientName: patient.name,
                      dispatchId:  activeDispatch!.id,
                    ),
                  )),
                  icon: const Icon(Icons.emergency_rounded, size: 14),
                  label: Text('Track', style: GoogleFonts.dmSans(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ]),
        ],
      ]),
    );
  }
}