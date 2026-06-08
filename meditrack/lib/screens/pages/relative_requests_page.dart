import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/relative_link_screen.dart';

class RelativeRequestsPage extends StatefulWidget {
  const RelativeRequestsPage({super.key});
  @override
  State<RelativeRequestsPage> createState() => _RelativeRequestsPageState();
}

class _RelativeRequestsPageState extends State<RelativeRequestsPage> {
  List<RelativeRequest> _requests = [];
  bool _loading = false;
  bool _busy    = false;
  String? _msg;
  bool _isError = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _msg = null; });
    final res = await apiService.getRelativeRequestsForPatient();
    if (!mounted) return;
    setState(() {
      _loading  = false;
      _requests = (res.data ?? [])
          .map((j) => RelativeRequest.fromJson(j as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _approve(int requestId) async {
    setState(() { _busy = true; _msg = null; });
    final res = await apiService.approveRelativeRequest(requestId);
    await _load();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _msg  = res.ok ? 'Relative approved and linked.' : (res.error ?? 'Failed.');
    });
  }

  Future<void> _reject(int requestId) async {
    setState(() { _busy = true; _msg = null; });
    final res = await apiService.rejectRelativeRequest(requestId);
    await _load();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _msg  = res.ok ? 'Request rejected.' : (res.error ?? 'Failed.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Relative Requests',
                    style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('People who want to follow your health status.',
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                if (_msg != null) ...[
                  const SizedBox(height: 12),
                  AlertWidget(message: _msg!, isError: _isError),
                ],
              ]),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(child: LoadingRows(count: 3))
          else if (_requests.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(message: 'No pending requests', icon: Icons.people_outline))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _RequestCard(
                    request:   _requests[i],
                    busy:      _busy,
                    onApprove: () => _approve(_requests[i].id),
                    onReject:  () => _reject(_requests[i].id),
                  ),
                  childCount: _requests.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final RelativeRequest request;
  final bool            busy;
  final VoidCallback    onApprove;
  final VoidCallback    onReject;
  const _RequestCard({required this.request, required this.busy,
      required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isPending = request.status == 'Pending';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarWidget(
            initials: request.relativeName.isNotEmpty
                ? request.relativeName[0].toUpperCase() : '?',
            size: 40, fontSize: 14),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(request.relativeName,
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(request.relationType,
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkAccent : AppColors.accent,
                    fontWeight: FontWeight.w500)),
            Text(request.relativePhone,
                style: GoogleFonts.dmSans(fontSize: 11.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          ])),
          BadgeWidget(
            label: request.status,
            type: request.status == 'Approved' ? BadgeType.green
                : request.status == 'Rejected'  ? BadgeType.red
                : BadgeType.amber,
          ),
        ]),
        if (isPending) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: busy ? null : onApprove,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.badgeGreenTxt,
                  foregroundColor: Colors.white),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: busy ? null : onReject,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
                side: BorderSide(
                    color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
              ),
            )),
          ]),
        ],
      ]),
    );
  }
}
