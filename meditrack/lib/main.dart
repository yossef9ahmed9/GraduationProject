import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/theme_provider.dart';
import 'package:meditrack/services/notification_provider.dart';
import 'package:meditrack/services/fcm_service.dart';
import 'package:meditrack/services/chat_service.dart';
import 'package:meditrack/services/location_service.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/screens/login_screen.dart';
import 'package:meditrack/screens/home_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialise Firebase (required before anything Firebase-related)
  await Firebase.initializeApp();
  FlutterNativeSplash.remove();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MediTrackApp(),
    ),
  );
}

class MediTrackApp extends StatelessWidget {
  const MediTrackApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      title: 'MediTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _Splash(),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fadeIn;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _pulse  = CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut));
    _ctrl.forward();
    _init();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _init() async {
    // Minimum splash display time
    final minDisplay = Future.delayed(const Duration(milliseconds: 2000));

    final auth   = context.read<AuthProvider>();
    final app    = context.read<AppProvider>();
    final notifs = context.read<NotificationProvider>();

    final restored = await auth.tryRestoreSession();
    if (!mounted) return;

    if (restored) {
      await app.loadAll(auth.role,
          patientEmail: auth.role == UserRole.patient ? auth.user?.email : null);
      await chatService.connect(auth.user!.token, auth.user!.email);
      notifs.init(auth.user!.email);
      await fcmService.init(
        userEmail: auth.user!.email,
        authToken: auth.user!.token,
      );
      fcmService.onMessageReceived = (title, body, data) {
        notifs.addFromFcm(title: title, body: body, data: data);
        // Emergency/dispatch push → حدّث vitals المريض المعني فوراً
        final type      = data['type']?.toString();
        final patientId = int.tryParse(data['patientId']?.toString() ?? '');

        if (type == 'emergency' || type == 'dispatch') {
          if (auth.role == UserRole.patient) {
            final patient = app.patientByEmail(auth.user!.email);
            if (patient != null) app.refreshMyVitals(patient.id);
          } else if (patientId != null) {
            // Doctor/Relative: حدّث vitals المريض المحدد فوراً
            apiService.getVitalsByPatient(patientId).then((res) {
              if (res.ok && res.data != null) {
                app.updateVitalsForPatient(patientId, res.data!);
              }
            });
          }
        }
      };
      if (auth.role == UserRole.patient) {
        final patient = app.patientByEmail(auth.user!.email);
        if (patient != null) locationService.startPatientTracking(patient.id);
      } else if (auth.role == UserRole.ambulance) {
        final myAmb = app.ambulances
            .where((a) => a.email.toLowerCase() == auth.user!.email.toLowerCase())
            .firstOrNull;
        if (myAmb != null) locationService.startAmbulanceTracking(myAmb.id);
      }
    }

    // Wait for both: init done AND minimum display time
    await minDisplay;
    if (!mounted) return;

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => restored ? const HomeScreen() : const LoginScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF000000) : const Color(0xFFF0F4FF);
    final circle = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
        : const Color(0xFF2563EB).withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [

        // ── Decorative corner circles ──────────────────────
        Positioned(top: -80, left: -80,
          child: _Circle(size: 260, color: circle)),
        Positioned(top: -60, right: -100,
          child: _Circle(size: 220, color: circle)),
        Positioned(bottom: -60, left: -60,
          child: _Circle(size: 240, color: circle)),
        Positioned(bottom: -40, right: -80,
          child: _Circle(size: 200, color: circle)),

        // ── Center content ─────────────────────────────────
        Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Logo icon
              ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(_fadeIn),
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // App name
              Text('MediTrack',
                  style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : const Color(0xFF0D1117),
                      letterSpacing: -0.5)),
              const SizedBox(height: 6),

              // Subtitle
              Text('Healthcare Management System',
                  style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
            ]),
          ),
        ),

        // ── Heartbeat line at bottom ───────────────────────
        Positioned(
          bottom: 48,
          left: 0, right: 0,
          child: FadeTransition(
            opacity: _pulse,
            child: Center(
              child: CustomPaint(
                size: const Size(160, 36),
                painter: _HeartbeatPainter(
                  color: isDark
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                      : const Color(0xFF2563EB).withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
        ),

      ]),
    );
  }
}

// ── Splash helpers ────────────────────────────────────────────

class _Circle extends StatelessWidget {
  final double size;
  final Color  color;
  const _Circle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _HeartbeatPainter extends CustomPainter {
  final Color color;
  const _HeartbeatPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final mid = h / 2;

    // Flat → spike up → spike down → flat  (ECG shape)
    path.moveTo(0, mid);
    path.lineTo(w * 0.25, mid);
    path.lineTo(w * 0.35, mid - h * 0.15);
    path.lineTo(w * 0.42, mid + h * 0.45);
    path.lineTo(w * 0.50, mid - h * 0.90);
    path.lineTo(w * 0.58, mid + h * 0.30);
    path.lineTo(w * 0.65, mid);
    path.lineTo(w, mid);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeartbeatPainter old) => old.color != color;
}
