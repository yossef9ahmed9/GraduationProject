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
import 'package:meditrack/screens/pages/progress_page.dart';
import 'package:meditrack/screens/pages/relative_requests_page.dart';
import 'package:meditrack/screens/pages/relative_chat_page.dart';
import 'package:meditrack/screens/pages/relative_patients_page.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/location_service.dart';

class _NavItem {
  final String id, label;
  final IconData icon;
  final String? section;
  const _NavItem(this.id, this.label, this.icon, {this.section});
}

const _patientNav = [
  _NavItem('dashboard',    'Home',          Icons.home_outlined,            section: 'Main'),
  _NavItem('doctors',      'Doctors',      Icons.medical_services_outlined),
  _NavItem('labs',         'Labs',         Icons.science_outlined),
  _NavItem('vitals',       'My Vitals',    Icons.monitor_heart_outlined,   section: 'Health'),
  _NavItem('progress',     'My Progress',  Icons.show_chart_rounded),
  _NavItem('tests',        'My Tests',     Icons.description_outlined),
  _NavItem('followups',    'Follow-ups',   Icons.assignment_outlined),
  _NavItem('requests',     'Link Requests',Icons.person_add_outlined),
  _NavItem('ambulances',   'Ambulances',   Icons.emergency_outlined,       section: 'Emergency'),
  _NavItem('profile',      'My Account',   Icons.person_outline,           section: 'Settings'),
];
const _doctorNav = [
  _NavItem('dashboard',  'Home',              Icons.home_outlined,       section: 'Main'),
  _NavItem('patients',   'My Patients',      Icons.people_outline),
  _NavItem('vitals',     'Vital Signs',      Icons.monitor_heart_outlined),
  _NavItem('progress',   'Patient Progress', Icons.show_chart_rounded),
  _NavItem('followups',  'Follow-ups',       Icons.assignment_outlined, section: 'Medical'),
  _NavItem('tests',      'Test Results',     Icons.description_outlined),
  _NavItem('profile',    'My Account',       Icons.person_outline,      section: 'Settings'),
];
const _labNav = [
  _NavItem('dashboard', 'Dashboard',   Icons.grid_view_rounded,   section: 'Main'),
  _NavItem('tests',     'Requests',    Icons.description_outlined),
  _NavItem('patients',  'Patients',    Icons.people_outline),
  _NavItem('profile',   'My Account',  Icons.person_outline,      section: 'Settings'),
];
const _relativeNav = [
  _NavItem('dashboard',       'Home',           Icons.home_outlined,            section: 'Main'),
  _NavItem('my-patients',     'My Patients',    Icons.people_outline),
  _NavItem('vitals',          'Patient Vitals', Icons.monitor_heart_outlined),
  _NavItem('progress',        'Progress',       Icons.show_chart_rounded),
  _NavItem('followups',       'Follow-ups',     Icons.assignment_outlined),
  _NavItem('relative-chat',   'Care Team',      Icons.chat_bubble_outline_rounded),
  _NavItem('ambulances',      'Ambulances',     Icons.emergency_outlined,       section: 'Emergency'),
  _NavItem('profile',         'My Account',     Icons.person_outline,           section: 'Settings'),
];
const _ambulanceNav = [
  _NavItem('dashboard',  'Dashboard',  Icons.grid_view_rounded,  section: 'Main'),
  _NavItem('ambulances', 'Dispatches', Icons.emergency_outlined),
  _NavItem('profile',    'My Account', Icons.person_outline,     section: 'Settings'),
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

Widget _buildPage(String id, UserRole role) {
  switch (id) {
    case 'dashboard':  return DashboardPage(role: role);
    case 'patients':   return const PatientsPage();
    case 'doctors':    return const DoctorsPage();
    case 'vitals':     return const VitalsPage();
    case 'labs':       return const LabsPage();
    case 'tests':      return const TestsPage();
    case 'followups':  return const FollowUpsPage();
    case 'sensors':    return const SensorsPage();
    case 'ambulances': return const AmbulancesPage();
    case 'profile':    return const ProfilePage();
    case 'progress':   return const ProgressPage();
    case 'requests':      return const RelativeRequestsPage();
    case 'my-patients':   return const RelativePatientsPage();
    case 'relative-chat': return const RelativeChatPage();
    case 'lab-request':return const LabRequestPage();
    default:           return const Center(child: Text('Page not found'));
  }
}

String _pageTitle(String id) {
  const titles = {
    'dashboard': 'Dashboard', 'patients': 'Patients', 'doctors': 'Doctors',
    'vitals': 'Vital Signs', 'labs': 'Labs', 'tests': 'Medical Tests',
    'followups': 'Follow-ups', 'ambulances': 'Ambulances', 'sensors': 'Sensors',
    'profile': 'My Account', 'lab-request': 'Lab Tests',
    'my-patients': 'My Patients', 'requests': 'Relative Requests',
    'relative-chat': 'Care Team',
  };
  return titles[id] ?? id;
}

class HomeNavigator {
  static _HomeScreenState? _of(BuildContext context) =>
      context.findAncestorStateOfType<_HomeScreenState>();
  static void go(BuildContext context, String pageId) => _of(context)?.navigateTo(pageId);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentPage = 'dashboard';
  void navigateTo(String pageId) => setState(() => _currentPage = pageId);

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final role  = auth.role;
    final nav   = _navForRole(role);
    final width = MediaQuery.of(context).size.width;
    if (width < 700) {
      return _MobileShell(nav: nav, role: role, user: auth.user,
          currentPage: _currentPage, onNavigate: navigateTo,
          child: _buildPage(_currentPage, role));
    }
    return _TabletShell(nav: nav, role: role, user: auth.user,
        currentPage: _currentPage, onNavigate: navigateTo,
        child: _buildPage(_currentPage, role));
  }
}

// ── Mobile Shell ──────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  final List<_NavItem> nav; final UserRole role; final AppUser? user;
  final String currentPage; final ValueChanged<String> onNavigate; final Widget child;
  const _MobileShell({required this.nav, required this.role, required this.user,
    required this.currentPage, required this.onNavigate, required this.child});

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
          // Notifications bell
          _NotifBell(onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()))),
          // Avatar
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
                      imageUrl: fullUrl,
                      cacheKey: fullUrl,
                      width: 30, height: 30, fit: BoxFit.cover,
                      placeholder: (_, __) => Center(child: Text(user?.initials ?? 'U',
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt))),
                      errorWidget: (_, __, ___) => Center(child: Text(user?.initials ?? 'U',
                          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt))),
                    ),
                  );
                }
                return Center(child: Text(user?.initials ?? 'U',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt)));
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
          if (auth.role == UserRole.ambulance) {
            await apiService.ambulanceSignOut();
          }
          locationService.stopPatientTracking();
          locationService.stopAmbulanceTracking();
          await auth.logout(); app.clear();
          if (context.mounted) Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
        },
      ),
      body: child,
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
}

// ── Tablet Shell ──────────────────────────────────────────────

class _TabletShell extends StatelessWidget {
  final List<_NavItem> nav; final UserRole role; final AppUser? user;
  final String currentPage; final ValueChanged<String> onNavigate; final Widget child;
  const _TabletShell({required this.nav, required this.role, required this.user,
    required this.currentPage, required this.onNavigate, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth   = context.read<AuthProvider>();
    final app    = context.read<AppProvider>();
    return Scaffold(body: Row(children: [
      Container(width: 210,
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
          Expanded(child: _SideNav(nav: nav, currentPage: currentPage, onNavigate: onNavigate)),
          _LogoutButton(onTap: () async {
            if (auth.role == UserRole.ambulance) {
              await apiService.ambulanceSignOut();
            }
            locationService.stopPatientTracking();
            locationService.stopAmbulanceTracking();
            await auth.logout(); app.clear();
            if (context.mounted) Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
          }),
        ]),
      ),
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
            // Notifications bell
            _NotifBell(onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()))),
            const SizedBox(width: 8),
            // Avatar + name
            InkWell(
              onTap: () => onNavigate('profile'),
              child: Row(children: [
                user?.profilePictureUrl != null
                    ? CircleAvatar(
                        radius: 14,
                        backgroundImage: NetworkImage(
                            '$serverBase${user!.profilePictureUrl}'),
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
        Expanded(child: child),
      ])),
    ]));
  }
}

// ── Side drawer ───────────────────────────────────────────────

class _SideDrawer extends StatelessWidget {
  final List<_NavItem> nav; final UserRole role; final AppUser? user;
  final String currentPage; final ValueChanged<String> onNavigate; final VoidCallback onLogout;
  const _SideDrawer({required this.nav, required this.role, required this.user,
    required this.currentPage, required this.onNavigate, required this.onLogout});

  Widget _logoIcon(bool isDark) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkLogoGradient : AppColors.logoGradient,
        borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 20));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? AppColors.darkBgSidebar : AppColors.bgSidebar,
      child: Column(children: [
        DrawerHeader(child: Row(children: [
          // Profile photo if available, else MediTrack icon
          Builder(builder: (context) {
            final picUrl = user?.profilePictureUrl;
            return picUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: '$serverBase$picUrl',
                    cacheKey: picUrl,
                    width: 36, height: 36, fit: BoxFit.cover,
                    placeholder: (_, __) => _logoIcon(isDark),
                    errorWidget: (_, __, ___) => _logoIcon(isDark),
                  ),
                )
              : _logoIcon(isDark);
          }),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('MediTrack', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(user?.name ?? '', style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          ]),
        ])),
        Expanded(child: _SideNav(nav: nav, currentPage: currentPage, onNavigate: onNavigate)),
        _LogoutButton(onTap: onLogout),
      ]),
    );
  }
}

// ── Side nav ──────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  final List<_NavItem> nav; final String currentPage; final ValueChanged<String> onNavigate;
  const _SideNav({required this.nav, required this.currentPage, required this.onNavigate});

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
                color: selected ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted) : null,
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

// ── Logout button ─────────────────────────────────────────────

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
              Text('Sign out', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Notifications bell ────────────────────────────────────────

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
              style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
            )),
          ),
        ),
    ]);
  }
}