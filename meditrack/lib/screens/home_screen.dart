import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/notification_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/login_screen.dart';
import 'package:meditrack/screens/pages/dashboard_page.dart';
import 'package:meditrack/screens/pages/patients_page.dart';
import 'package:meditrack/screens/pages/doctors_page.dart';
import 'package:meditrack/screens/pages/vitals_page.dart';
import 'package:meditrack/screens/pages/labs_page.dart';
import 'package:meditrack/screens/pages/tests_page.dart';
import 'package:meditrack/screens/pages/followups_page.dart';
import 'package:meditrack/screens/pages/sensors_page.dart';
import 'package:meditrack/screens/pages/ambulances_page.dart';
import 'package:meditrack/screens/pages/profile_page.dart';
import 'package:meditrack/screens/pages/notifications_page.dart';
import 'package:meditrack/screens/pages/lab_request_page.dart';
import 'package:meditrack/screens/pages/patient_file_page.dart';
import 'package:meditrack/screens/pages/progress_page.dart';
import 'package:meditrack/screens/pages/relative_requests_page.dart';
import 'package:meditrack/screens/pages/relative_chat_page.dart';
import 'package:meditrack/screens/pages/relative_patients_page.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/location_service.dart';

// ─────────────────────────────────────────────────────────────
// NAV ITEMS
// ─────────────────────────────────────────────────────────────

class _NavItem {
  final String id, label;
  final IconData icon;
  final String? section;
  const _NavItem(this.id, this.label, this.icon, {this.section});
}

const _patientNav = [
  _NavItem('dashboard',    'Home',           Icons.home_outlined,            section: 'Main'),
  _NavItem('doctors',      'Doctors',        Icons.medical_services_outlined),
  _NavItem('labs',         'Labs',           Icons.science_outlined),
  _NavItem('vitals',       'My Vitals',      Icons.monitor_heart_outlined,   section: 'Health'),
  _NavItem('patient-file', 'Health File',    Icons.folder_open_rounded),
  _NavItem('tests',        'My Tests',       Icons.description_outlined),
  _NavItem('followups',    'Follow-ups',     Icons.assignment_outlined),
  _NavItem('requests',     'Link Requests',  Icons.person_add_outlined),
  _NavItem('profile',      'My Account',     Icons.person_outline,           section: 'Settings'),
];
const _doctorNav = [
  _NavItem('dashboard',    'Home',           Icons.home_outlined,            section: 'Main'),
  _NavItem('patients',     'My Patients',    Icons.people_outline),
  _NavItem('vitals',       'Vital Signs',    Icons.monitor_heart_outlined),
  _NavItem('patient-file', 'Patient File',   Icons.folder_open_rounded),
  _NavItem('followups',    'Follow-ups',     Icons.assignment_outlined,      section: 'Medical'),
  _NavItem('tests',        'Test Results',   Icons.description_outlined),
  _NavItem('profile',      'My Account',     Icons.person_outline,           section: 'Settings'),
];
const _labNav = [
  _NavItem('dashboard', 'Dashboard',   Icons.grid_view_rounded,    section: 'Main'),
  _NavItem('tests',     'Requests',    Icons.description_outlined),
  _NavItem('patients',  'Patients',    Icons.people_outline),
  _NavItem('profile',   'My Account',  Icons.person_outline,       section: 'Settings'),
];
const _relativeNav = [
  _NavItem('dashboard',     'Home',           Icons.home_outlined,               section: 'Main'),
  _NavItem('my-patients',   'My Patients',    Icons.people_outline),
  _NavItem('vitals',        'Patient Vitals', Icons.monitor_heart_outlined),
  _NavItem('patient-file',  'Health File',    Icons.folder_open_rounded),
  _NavItem('followups',     'Follow-ups',     Icons.assignment_outlined),
  _NavItem('relative-chat', 'Care Team',      Icons.chat_bubble_outline_rounded),
  _NavItem('profile',       'My Account',     Icons.person_outline,              section: 'Settings'),
];
const _ambulanceNav = [
  _NavItem('dashboard',  'Dashboard',  Icons.grid_view_rounded,   section: 'Main'),
  _NavItem('ambulances', 'Dispatches', Icons.emergency_outlined),
  _NavItem('profile',    'My Account', Icons.person_outline,      section: 'Settings'),
];
const _adminNav = [
  _NavItem('dashboard',  'Dashboard',   Icons.grid_view_rounded,        section: 'Main'),
  _NavItem('patients',   'Patients',    Icons.people_outline),
  _NavItem('doctors',    'Doctors',     Icons.medical_services_outlined),
  _NavItem('vitals',     'Vital Signs', Icons.monitor_heart_outlined),
  _NavItem('labs',       'Labs',        Icons.science_outlined,         section: 'Medical'),
  _NavItem('tests',      'Tests',       Icons.description_outlined),
  _NavItem('followups',  'Follow-ups',  Icons.assignment_outlined),
  _NavItem('ambulances', 'Ambulances',  Icons.emergency_outlined,       section: 'Emergency'),
  _NavItem('sensors',    'Sensors',     Icons.sensors_outlined,         section: 'System'),
  _NavItem('profile',    'My Account',  Icons.person_outline),
];

List<_NavItem> _navForRole(UserRole role) {
  switch (role) {
    case UserRole.patient:   return _patientNav;
    case UserRole.doctor:    return _doctorNav;
    case UserRole.lab:       return _labNav;
    case UserRole.relative:  return _relativeNav;
    case UserRole.ambulance: return _ambulanceNav;
    default:                 return _adminNav;
  }
}

// ─────────────────────────────────────────────────────────────
// PAGE BUILDER
// ─────────────────────────────────────────────────────────────

Widget _buildPage(String id, UserRole role) {
  switch (id) {
    case 'dashboard':     return DashboardPage(role: role);
    case 'patients':      return const PatientsPage();
    case 'doctors':       return const DoctorsPage();
    case 'vitals':        return const VitalsPage();
    case 'labs':          return const LabsPage();
    case 'tests':         return const TestsPage();
    case 'followups':     return const FollowUpsPage();
    case 'sensors':       return const SensorsPage();
    case 'ambulances':    return const AmbulancesPage();
    case 'profile':       return const ProfilePage();
    case 'progress':      return const ProgressPage();
    case 'patient-file':  return const PatientFilePage();
    case 'requests':      return const RelativeRequestsPage();
    case 'my-patients':   return const RelativePatientsPage();
    case 'relative-chat': return const RelativeChatPage();
    case 'lab-request':   return const LabRequestPage();
    default:              return const Center(child: Text('Page not found'));
  }
}

String _pageTitle(String id) {
  const titles = {
    'dashboard': 'Dashboard',      'patients': 'Patients',
    'doctors': 'Doctors',          'vitals': 'Vital Signs',
    'labs': 'Labs',                'tests': 'Medical Tests',
    'followups': 'Follow-ups',     'ambulances': 'Ambulances',
    'sensors': 'Sensors',          'profile': 'My Account',
    'lab-request': 'Lab Tests',    'my-patients': 'My Patients',
    'requests': 'Relative Requests', 'relative-chat': 'Care Team',
    'patient-file': 'Health File', 'progress': 'Progress',
  };
  return titles[id] ?? id;
}

// ─────────────────────────────────────────────────────────────
// HOME NAVIGATOR (static helper)
// ─────────────────────────────────────────────────────────────

class HomeNavigator {
  static _HomeScreenState? _of(BuildContext context) =>
      context.findAncestorStateOfType<_HomeScreenState>();
  static void go(BuildContext context, String pageId) =>
      _of(context)?.navigateTo(pageId);
}

// ─────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentPage = 'dashboard';

  // Tracks vital IDs whose dialog has already been shown THIS session.
  // Cleared when the vital is no longer in the emergency list (patient recovered).
  final Set<int> _shownVitalIds = {};
  final Set<String> _shownNotifIds = {};

  // Whether an emergency dialog is currently open — prevents stacking.
  bool _dialogOpen = false;

  // Polls vitals every 20s for emergency detection and recovery.
  Timer? _vitalsTimer;

  void navigateTo(String pageId) => setState(() => _currentPage = pageId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVitalsPolling();
      // For patient role: load their vitals immediately on home screen open
      final app  = context.read<AppProvider>();
      final auth = context.read<AuthProvider>();
      if (auth.role == UserRole.patient) {
        final me = app.patientByEmail(auth.user?.email ?? '');
        if (me != null) app.refreshMyVitals(me.id);
      }
    });
  }

  void _startVitalsPolling() {
    _vitalsTimer?.cancel();
    _vitalsTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final app  = context.read<AppProvider>();
      final auth = context.read<AuthProvider>();
      final role = auth.role;

      switch (role) {
        case UserRole.patient:
          // مريض → يحدث vitals نفسه بس
          final me = app.patientByEmail(auth.user?.email ?? '');
          if (me != null) app.refreshMyVitals(me.id);
          break;

        case UserRole.doctor:
        case UserRole.relative:
          // دكتور/قريب → كل مريض مرتبط بيه بشكل منفصل
          for (final patient in app.patients) {
            apiService.getVitalsByPatient(patient.id).then((res) {
              if (res.ok && res.data != null && mounted) {
                app.updateVitalsForPatient(patient.id, res.data!);
              }
            });
          }
          break;

        case UserRole.lab:
        case UserRole.ambulance:
          break; // مش محتاجين vitals polling

        default:
          // Admin
          app.refreshVitals(null);
      }
    });
  }

  @override
  void dispose() {
    _vitalsTimer?.cancel();
    super.dispose();
  }

  // ── Compute scoped emergency vitals ───────────────────────────
  List<VitalSignsResponse> _scopedEmergencies(
      AppProvider app, AuthProvider auth) {
    final role = auth.role;
    switch (role) {
      case UserRole.lab:
        return [];
      case UserRole.doctor:
      case UserRole.relative:
        final myIds = app.patients.map((p) => p.id).toSet();
        return app.emergencyVitals
            .where((v) => myIds.contains(v.patientId))
            .toList();
      case UserRole.patient:
        // Patient: use myVitals — only the LATEST reading matters
        if (app.myVitals.isEmpty) return [];
        final latest = app.myVitals.reduce((a, b) {
          final aTs = DateTime.tryParse(a.timeStamp) ?? DateTime(0);
          final bTs = DateTime.tryParse(b.timeStamp) ?? DateTime(0);
          return bTs.isAfter(aTs) ? b : a;
        });
        return latest.emergencyStatus ? [latest] : [];
      case UserRole.ambulance:
        // For ambulance, treat active dispatches as the signal
        return app.emergencyVitals; // vignette only; dialog from notifs
      default: // admin
        return app.emergencyVitals;
    }
  }

  bool _hasEmergency(AppProvider app, AuthProvider auth) {
    final role = auth.role;
    if (role == UserRole.lab) return false;
    if (role == UserRole.ambulance) return app.activeDispatches.isNotEmpty;
    return _scopedEmergencies(app, auth).isNotEmpty;
  }

  // ── Show dialog if needed ─────────────────────────────────────
  void _maybeShowDialog() {
    if (_dialogOpen) return;
    // Run immediately after build so overlay is ready — no extra frame delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogOpen) return;

      final app    = context.read<AppProvider>();
      final auth   = context.read<AuthProvider>();
      final notifs = context.read<NotificationProvider>();

      // Remove IDs for vitals no longer in emergency so re-alerts work
      final currentEmergencyIds = app.emergencyVitals.map((v) => v.id).toSet();
      _shownVitalIds.removeWhere((id) => !currentEmergencyIds.contains(id));

      final scoped = _scopedEmergencies(app, auth);

      // 1. Emergency vitals
      for (final vital in scoped) {
        if (!_shownVitalIds.contains(vital.id)) {
          _shownVitalIds.add(vital.id);
          _dialogOpen = true;
          final rawName = app.patientName(vital.patientId);
          final name = (rawName != null && rawName.isNotEmpty)
              ? rawName
              : vital.patientName.isNotEmpty
                  ? vital.patientName
                  : 'Patient #${vital.patientId}';
          EmergencyAlertDialog.show(
            context,
            patientName: name,
            message: _buildVitalMsg(vital),
            actionLabel: 'View Vitals',
            onAction: () {
              _dialogOpen = false;
              Navigator.of(context, rootNavigator: true).pop();
              navigateTo('vitals');
            },
          ).whenComplete(() => _dialogOpen = false);
          return;
        }
      }

      // 2. FCM / push emergency notifications
      for (final notif in notifs.all) {
        if (notif.type == NotifType.emergency &&
            !_shownNotifIds.contains(notif.id)) {
          _shownNotifIds.add(notif.id);
          _dialogOpen = true;
          EmergencyAlertDialog.show(
            context,
            patientName: notif.title.replaceAll('🚨 Emergency — ', ''),
            message: notif.body,
            actionLabel: 'View Vitals',
            onAction: () {
              _dialogOpen = false;
              Navigator.of(context, rootNavigator: true).pop();
              navigateTo('vitals');
            },
          ).whenComplete(() => _dialogOpen = false);
          return;
        }
      }
    });
  }

  String _buildVitalMsg(VitalSignsResponse v) {
    final parts = <String>[];
    if (v.heartRate > 100) parts.add('Heart rate ${v.heartRate} bpm (elevated)');
    if (v.heartRate < 60 && v.heartRate > 0)
      parts.add('Heart rate ${v.heartRate} bpm (too low)');
    if ((v.oxygenSaturation ?? 100) < 95)
      parts.add('SpO₂ ${v.oxygenSaturation?.toStringAsFixed(1)}% (critically low)');
    if (parts.isEmpty) parts.add('Abnormal vitals — immediate attention required.');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final app  = context.watch<AppProvider>();
    context.watch<NotificationProvider>();

    // Trigger dialog check on every rebuild caused by provider changes
    _maybeShowDialog();

    final role  = auth.role;
    final nav   = _navForRole(role);
    final width = MediaQuery.of(context).size.width;

    final hasEmergency = _hasEmergency(app, auth);

    if (width < 700) {
      return _MobileShell(
        nav: nav, role: role, user: auth.user,
        currentPage: _currentPage, onNavigate: navigateTo,
        hasEmergency: hasEmergency,
        child: _buildPage(_currentPage, role),
      );
    }
    return _TabletShell(
      nav: nav, role: role, user: auth.user,
      currentPage: _currentPage, onNavigate: navigateTo,
      hasEmergency: hasEmergency,
      child: _buildPage(_currentPage, role),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MOBILE SHELL
// ─────────────────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  final List<_NavItem> nav;
  final UserRole role;
  final AppUser? user;
  final String currentPage;
  final ValueChanged<String> onNavigate;
  final Widget child;
  final bool hasEmergency;

  const _MobileShell({
    required this.nav, required this.role, required this.user,
    required this.currentPage, required this.onNavigate,
    required this.child, required this.hasEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth   = context.read<AuthProvider>();
    final app    = context.read<AppProvider>();
    final bottomItems = nav.take(5).toList();
    final idx = bottomItems.indexWhere((n) => n.id == currentPage);

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle(currentPage)),
        actions: [
          _NotifBell(onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()))),
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 30, height: 30,
            decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
                shape: BoxShape.circle),
            child: InkWell(
              onTap: () => onNavigate('profile'),
              child: Builder(builder: (context) {
                final picUrl = user?.profilePictureUrl;
                if (picUrl != null && picUrl.isNotEmpty) {
                  final fullUrl = '$serverBase$picUrl';
                  return ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: fullUrl, cacheKey: fullUrl,
                      width: 30, height: 30, fit: BoxFit.cover,
                      placeholder: (_, __) => _initialsWidget(isDark),
                      errorWidget: (_, __, ___) => _initialsWidget(isDark),
                    ),
                  );
                }
                return _initialsWidget(isDark);
              }),
            ),
          ),
        ],
      ),
      drawer: _SideDrawer(
        nav: nav, role: role, user: user,
        currentPage: currentPage,
        onNavigate: (id) { Navigator.of(context).pop(); onNavigate(id); },
        onLogout: () async {
          Navigator.of(context).pop();
          if (auth.role == UserRole.ambulance) await apiService.ambulanceSignOut();
          locationService.stopPatientTracking();
          locationService.stopAmbulanceTracking();
          await auth.logout(); app.clear();
          if (context.mounted) Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        },
      ),
      // Vignette wraps only the body content
      body: _EmergencyVignette(
        active: hasEmergency,
        child: Column(children: [
          Expanded(child: child),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx < 0 ? 0 : idx,
        backgroundColor: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
        onDestinationSelected: (i) => onNavigate(bottomItems[i].id),
        destinations: bottomItems
            .map((n) => NavigationDestination(icon: Icon(n.icon, size: 22), label: n.label))
            .toList(),
      ),
    );
  }

  Widget _initialsWidget(bool isDark) => Center(
    child: Text(user?.initials ?? 'U',
        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt)),
  );
}

// ─────────────────────────────────────────────────────────────
// TABLET SHELL
// ─────────────────────────────────────────────────────────────

class _TabletShell extends StatelessWidget {
  final List<_NavItem> nav;
  final UserRole role;
  final AppUser? user;
  final String currentPage;
  final ValueChanged<String> onNavigate;
  final Widget child;
  final bool hasEmergency;

  const _TabletShell({
    required this.nav, required this.role, required this.user,
    required this.currentPage, required this.onNavigate,
    required this.child, required this.hasEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth   = context.read<AuthProvider>();
    final app    = context.read<AppProvider>();

    return Scaffold(
      body: Row(children: [
        // ── Sidebar ──
        Container(
          width: 210,
          decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgSidebar : AppColors.bgSidebar,
              border: Border(right: BorderSide(
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
              child: Row(children: [
                Container(width: 28, height: 28,
                    decoration: BoxDecoration(
                        gradient: isDark ? AppColors.darkLogoGradient : AppColors.logoGradient,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 16)),
                const SizedBox(width: 8),
                Text('MediTrack', style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              ]),
            ),
            Expanded(child: _SideNav(
                nav: nav, currentPage: currentPage, onNavigate: onNavigate)),
            _LogoutButton(onTap: () async {
              if (auth.role == UserRole.ambulance) await apiService.ambulanceSignOut();
              locationService.stopPatientTracking();
              locationService.stopAmbulanceTracking();
              await auth.logout(); app.clear();
              if (context.mounted) Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            }),
          ]),
        ),
        // ── Main area ──
        Expanded(child: Column(children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
                border: Border(bottom: BorderSide(
                    color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
            child: Row(children: [
              Text(_pageTitle(currentPage), style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              const Spacer(),
              _NotifBell(onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()))),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => onNavigate('profile'),
                child: Row(children: [
                  user?.profilePictureUrl != null
                      ? CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage('$serverBase${user!.profilePictureUrl}'),
                          onBackgroundImageError: (_, __) {},
                        )
                      : AvatarWidget(initials: user?.initials ?? 'U'),
                  const SizedBox(width: 8),
                  Text(user?.name ?? '',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),
          // Vignette wraps the page content area
          Expanded(child: _EmergencyVignette(active: hasEmergency, child: child)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SIDE DRAWER
// ─────────────────────────────────────────────────────────────

class _SideDrawer extends StatelessWidget {
  final List<_NavItem> nav; final UserRole role; final AppUser? user;
  final String currentPage; final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  const _SideDrawer({required this.nav, required this.role, required this.user,
    required this.currentPage, required this.onNavigate, required this.onLogout});

  Widget _logoIcon(bool isDark) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? AppColors.darkBgSidebar : AppColors.bgSidebar,
      child: Column(children: [
        DrawerHeader(child: Row(children: [
          Builder(builder: (context) {
            final picUrl = user?.profilePictureUrl;
            return picUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: '$serverBase$picUrl', cacheKey: picUrl,
                      width: 36, height: 36, fit: BoxFit.cover,
                      placeholder: (_, __) => _logoIcon(isDark),
                      errorWidget: (_, __, ___) => _logoIcon(isDark),
                    ),
                  )
                : _logoIcon(isDark);
          }),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('MediTrack', style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w700)),
            Text(user?.name ?? '', style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          ]),
        ])),
        Expanded(child: _SideNav(
            nav: nav, currentPage: currentPage, onNavigate: onNavigate)),
        _LogoutButton(onTap: onLogout),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SIDE NAV
// ─────────────────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  final List<_NavItem> nav;
  final String currentPage;
  final ValueChanged<String> onNavigate;
  const _SideNav({required this.nav, required this.currentPage,
    required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? lastSection;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: nav.map((item) {
        final List<Widget> widgets = [];
        if (item.section != null && item.section != lastSection) {
          lastSection = item.section;
          widgets.add(SectionHeader(label: item.section!));
        }
        final selected = currentPage == item.id;
        widgets.add(Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onNavigate(item.id),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(item.icon, size: 16,
                    color: selected
                        ? (isDark ? AppColors.darkAccent : AppColors.accent)
                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                const SizedBox(width: 9),
                Text(item.label, style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? (isDark ? AppColors.darkAccent : AppColors.accent)
                      : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                )),
              ]),
            ),
          ),
        ));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LOGOUT BUTTON
// ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(
          color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(Icons.logout_rounded, size: 14,
                  color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
              const SizedBox(width: 9),
              Text('Sign out', style: GoogleFonts.dmSans(fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NOTIFICATIONS BELL
// ─────────────────────────────────────────────────────────────

class _NotifBell extends StatelessWidget {
  final VoidCallback onTap;
  const _NotifBell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count  = context.watch<NotificationProvider>().unreadCount;
    return Stack(children: [
      IconButton(
        onPressed: onTap,
        icon: Icon(
          count > 0 ? Icons.notifications_rounded : Icons.notifications_outlined,
          size: 22,
        ),
        tooltip: 'Notifications',
      ),
      if (count > 0)
        Positioned(
          top: 6, right: 6,
          child: Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
                color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
                shape: BoxShape.circle),
            child: Center(child: Text(
              count > 9 ? '9+' : '$count',
              style: GoogleFonts.dmSans(fontSize: 9,
                  fontWeight: FontWeight.w700, color: Colors.white),
            )),
          ),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// EMERGENCY VIGNETTE
// Pulsing red corner glow. active=true → show, active=false → gone.
// ─────────────────────────────────────────────────────────────

class _EmergencyVignette extends StatefulWidget {
  final Widget child;
  final bool active;
  const _EmergencyVignette({required this.child, required this.active});

  @override
  State<_EmergencyVignette> createState() => _EmergencyVignetteState();
}

class _EmergencyVignetteState extends State<_EmergencyVignette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.active)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => CustomPaint(
                painter: _VignettePainter(_pulse.value),
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws a radial red glow bleeding in from all four corners.
class _VignettePainter extends CustomPainter {
  final double intensity; // 0.0 – 1.0
  const _VignettePainter(this.intensity);

  static const _red = Color(0xFFDC2626);

  @override
  void paint(Canvas canvas, Size size) {
    final corners = [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    for (final corner in corners) {
      final radius = size.shortestSide * 0.72;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            _red.withOpacity(0.55 * intensity),
            _red.withOpacity(0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: corner, radius: radius));
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_VignettePainter old) => old.intensity != intensity;
}
