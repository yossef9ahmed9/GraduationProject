import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/home_screen.dart';

// ════════════════════════════════════════════════════════════════
// RelativeLinkScreen
// Shows all patients in a searchable list — relative picks their
// patient and sends a link request. Patient must then approve it.
// ════════════════════════════════════════════════════════════════
class RelativeLinkScreen extends StatefulWidget {
  const RelativeLinkScreen({super.key});
  @override
  State<RelativeLinkScreen> createState() => _RelativeLinkScreenState();
}

class _RelativeLinkScreenState extends State<RelativeLinkScreen> {
  final _searchCtrl = TextEditingController();
  List<PatientSearchResult> _all     = [];
  List<PatientSearchResult> _visible = [];
  bool   _loading          = false;
  bool   _sending          = false;
  String? _msg;
  bool   _isError          = false;
  int?   _sentToPatientId;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // Load all patients once on open
  Future<void> _loadAll() async {
    setState(() { _loading = true; _msg = null; });
    final res = await apiService.getPatients(pageSize: 500);
    if (!mounted) return;
    final list = (res.data ?? [])
        .map((p) => PatientSearchResult(
              id:     p.id,
              name:   p.name,
              email:  p.email,
              phone:  p.phone,
              gender: p.gender,
            ))
        .toList();
    setState(() {
      _loading = false;
      _all     = list;
      _visible = list;
    });
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _visible = query.isEmpty
          ? _all
          : _all.where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.email.toLowerCase().contains(query) ||
              p.phone.contains(query)).toList();
    });
  }

  Future<void> _sendRequest(PatientSearchResult patient) async {
    setState(() { _sending = true; _msg = null; });
    final res = await apiService.sendRelativeRequest(patient.id);
    if (!mounted) return;
    setState(() {
      _sending         = false;
      _isError         = !res.ok;
      _sentToPatientId = res.ok ? patient.id : null;
      _msg = res.ok
          ? 'Request sent to ${patient.name}. Waiting for their approval.'
          : (res.error ?? 'Failed to send request.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Your Patient'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false),
            child: Text('Skip',
                style: GoogleFonts.dmSans(
                    color: isDark ? AppColors.darkAccent : AppColors.accent)),
          ),
        ],
      ),
      body: Column(children: [
        // Header + search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Select your patient',
                style: GoogleFonts.dmSans(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text("Find the patient you want to follow and send them a link request.",
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              AlertWidget(message: _msg!, isError: _isError),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged:  _filter,
              decoration: InputDecoration(
                hintText: 'Search by name, email or phone…',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter('');
                        })
                    : null,
              ),
            ),
          ]),
        ),

        // Count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${_visible.length} patient${_visible.length != 1 ? 's' : ''}',
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const LoadingRows(count: 6)
              : _visible.isEmpty
                  ? EmptyState(
                      message: _searchCtrl.text.isEmpty
                          ? 'No patients found'
                          : 'No patients match your search',
                      icon: Icons.people_outline,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _visible.length,
                      itemBuilder: (_, i) {
                        final p    = _visible[i];
                        final sent = _sentToPatientId == p.id;
                        return AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            AvatarWidget(
                                initials: p.initials, size: 40, fontSize: 14),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(p.name,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(p.email,
                                  style: GoogleFonts.dmSans(fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary)),
                              if (p.phone.isNotEmpty)
                                Text(p.phone,
                                    style: GoogleFonts.dmSans(fontSize: 11.5,
                                        color: isDark
                                            ? AppColors.darkTextTertiary
                                            : AppColors.textTertiary)),
                            ])),
                            const SizedBox(width: 8),
                            sent
                                ? const BadgeWidget(
                                    label: 'Sent', type: BadgeType.green)
                                : ElevatedButton(
                                    onPressed: _sending
                                        ? null
                                        : () => _sendRequest(p),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: _sending
                                        ? const SizedBox(
                                            width: 14, height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : Text('Request',
                                            style: GoogleFonts.dmSans(
                                                fontSize: 12)),
                                  ),
                          ]),
                        );
                      },
                    ),
        ),

        // Go to home after sending
        if (_sentToPatientId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PrimaryButton(
              label: 'Go to Dashboard',
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (_) => false),
            ),
          ),
      ]),
    );
  }
}
