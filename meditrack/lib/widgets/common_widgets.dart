
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// Base URL for serving backend-hosted images
const String _avatarBase = 'http://192.168.1.6:5098';

// ── Avatar ────────────────────────────────────────────────────
class AvatarWidget extends StatelessWidget {
  final String initials;
  final double size;
  final double fontSize;
  /// Optional profile picture URL (relative path from the backend).
  /// If provided and non-empty, shows the photo instead of initials.
  final String? photoUrl;

  const AvatarWidget({
    super.key,
    required this.initials,
    this.size = 32,
    this.fontSize = 11,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fullUrl = (photoUrl != null && photoUrl!.isNotEmpty)
        ? '$_avatarBase$photoUrl'
        : null;

    if (fullUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: fullUrl,
          cacheKey: fullUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _initialsCircle(isDark),
          errorWidget: (_, __, ___) => _initialsCircle(isDark),
        ),
      );
    }

    return _initialsCircle(isDark);
  }

  Widget _initialsCircle(bool isDark) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: isDark
          ? const LinearGradient(colors: [Color(0x4D2563EB), Color(0x661E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight)
          : const LinearGradient(colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)],
    ),
    child: Center(child: Text(initials, style: GoogleFonts.dmSans(fontSize: fontSize, fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt))),
  );
}

// ── Badge ─────────────────────────────────────────────────────
enum BadgeType { green, red, blue, amber, purple }

class BadgeWidget extends StatelessWidget {
  final String label;
  final BadgeType type;
  const BadgeWidget({super.key, required this.label, this.type = BadgeType.blue});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg, txt;
    switch (type) {
      case BadgeType.green:  bg = isDark ? AppColors.darkBadgeGreenBg  : AppColors.badgeGreenBg;  txt = isDark ? AppColors.darkBadgeGreenTxt  : AppColors.badgeGreenTxt;  break;
      case BadgeType.red:    bg = isDark ? AppColors.darkBadgeRedBg    : AppColors.badgeRedBg;    txt = isDark ? AppColors.darkBadgeRedTxt    : AppColors.badgeRedTxt;    break;
      case BadgeType.amber:  bg = isDark ? AppColors.darkBadgeAmberBg  : AppColors.badgeAmberBg;  txt = isDark ? AppColors.darkBadgeAmberTxt  : AppColors.badgeAmberTxt;  break;
      case BadgeType.purple: bg = isDark ? AppColors.darkBadgePurpleBg : AppColors.badgePurpleBg; txt = isDark ? AppColors.darkBadgePurpleTxt : AppColors.badgePurpleTxt; break;
      default:               bg = isDark ? AppColors.darkBadgeBlueBg   : AppColors.badgeBlueBg;   txt = isDark ? AppColors.darkBadgeBlueTxt   : AppColors.badgeBlueTxt;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w600, color: txt, letterSpacing: 0.02)),
    );
  }
}

// ── App Card ──────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: padding != null ? Padding(padding: padding!, child: child) : child,
        ),
      ),
    );
  }
}

// ── Card Header ───────────────────────────────────────────────
class CardHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const CardHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F7FB),
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  const StatCard({super.key, required this.label, required this.value, this.subtitle, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.dmMono(fontSize: 24, fontWeight: FontWeight.w600,
                color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 10.5, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          ],
        ],
      ),
    );
  }
}

// ── Vital Card ────────────────────────────────────────────────
class VitalCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;
  const VitalCard({super.key, required this.label, required this.value, required this.unit, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.04)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.dmMono(fontSize: 22, fontWeight: FontWeight.w600,
                color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary), letterSpacing: -0.5)),
          ),
          Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 10, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ],
      ),
    );
  }
}

// ── Emergency Banner ──────────────────────────────────────────
class EmergencyBanner extends StatelessWidget {
  final String text;
  final VoidCallback? onViewVitals;
  const EmergencyBanner({super.key, required this.text, this.onViewVitals});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkEmergencyBg : AppColors.emergencyBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkEmergencyBdr : AppColors.emergencyBdr),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: isDark ? AppColors.darkEmergencyIco : AppColors.emergencyIco),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkEmergencyTxt : AppColors.emergencyTxt))),
        if (onViewVitals != null) TextButton(
          onPressed: onViewVitals,
          child: Text('View', style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkAccent : AppColors.accent, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Alert Widget ──────────────────────────────────────────────
class AlertWidget extends StatelessWidget {
  final String message;
  final bool isError;
  const AlertWidget({super.key, required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg  = isError ? (isDark ? AppColors.darkBadgeRedBg  : AppColors.alertErrBg)  : (isDark ? AppColors.darkBadgeGreenBg  : AppColors.alertOkBg);
    final txt = isError ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.alertErrTxt) : (isDark ? AppColors.darkBadgeGreenTxt : AppColors.alertOkTxt);
    final bdr = isError ? (isDark ? AppColors.darkBadgeRedTxt.withOpacity(0.3) : AppColors.alertErrBdr) : (isDark ? AppColors.darkBadgeGreenTxt.withOpacity(0.3) : AppColors.alertOkBdr);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9), border: Border.all(color: bdr)),
      child: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, size: 16, color: txt),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: GoogleFonts.dmSans(fontSize: 13, color: txt))),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ]),
      ),
    );
  }
}

// ── Loading Rows ──────────────────────────────────────────────
class LoadingRows extends StatelessWidget {
  final int count;
  const LoadingRows({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(count, (_) => const _SkeletonRow()));
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E7EB),
          shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 12, width: 140, decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Container(height: 10, width: 90, decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(4))),
        ])),
      ]),
    );
  }
}

// ── Primary Button ────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.isLoading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
                Text(label),
              ]),
      ),
    );
  }
}

// ── Emergency Alert Dialog ────────────────────────────────────
class EmergencyAlertDialog extends StatefulWidget {
  final String patientName;
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;
  final String actionLabel;

  const EmergencyAlertDialog({
    super.key,
    required this.patientName,
    required this.message,
    this.onDismiss,
    this.onAction,
    this.actionLabel = 'View Details',
  });

  /// Shows the emergency dialog centered on screen.
  static Future<void> show(
    BuildContext context, {
    required String patientName,
    required String message,
    VoidCallback? onAction,
    String actionLabel = 'View Details',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => EmergencyAlertDialog(
        patientName: patientName,
        message: message,
        onAction: onAction,
        actionLabel: actionLabel,
        onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    );
  }

  @override
  State<EmergencyAlertDialog> createState() => _EmergencyAlertDialogState();
}

class _EmergencyAlertDialogState extends State<EmergencyAlertDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.12).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors — always red regardless of theme
    const redDeep   = Color(0xFF7F1D1D);   // dark red bg in dark mode
    const redBg     = Color(0xFFFEF2F2);   // light red bg in light mode
    const redBorder = Color(0xFFEF4444);   // vivid red border
    const redVivid  = Color(0xFFDC2626);   // icon / accent
    const redText   = Color(0xFF991B1B);   // body text light
    const redTextDk = Color(0xFFFCA5A5);   // body text dark
    const redTitle  = Color(0xFFB91C1C);   // title light
    const redTitleDk= Color(0xFFF87171);   // title dark

    final bgColor     = isDark ? const Color(0xFF1A0A0A) : redBg;
    final titleColor  = isDark ? redTitleDk : redTitle;
    final textColor   = isDark ? redTextDk  : redText;
    final borderColor = isDark ? redBorder.withOpacity(0.55) : redBorder.withOpacity(0.45);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: redVivid.withOpacity(isDark ? 0.35 : 0.18),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: BoxDecoration(
                  color: redVivid.withOpacity(isDark ? 0.18 : 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  border: Border(
                    bottom: BorderSide(color: borderColor),
                  ),
                ),
                child: Row(children: [
                  // Pulsing icon
                  ScaleTransition(
                    scale: _pulse,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: redVivid.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: redVivid.withOpacity(0.4)),
                      ),
                      child: const Icon(
                        Icons.emergency_rounded,
                        color: redVivid,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EMERGENCY ALERT',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: redVivid,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          widget.patientName,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close X
                  InkWell(
                    onTap: widget.onDismiss ?? () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: textColor),
                    ),
                  ),
                ]),
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Actions ──
                    Row(children: [
                      // Dismiss
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onDismiss ?? () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            textStyle: GoogleFonts.dmSans(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Dismiss'),
                        ),
                      ),
                      if (widget.onAction != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: redVivid,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                              textStyle: GoogleFonts.dmSans(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            child: Text(widget.actionLabel),
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String label;
  const SectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(label.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary, letterSpacing: 0.08)),
    );
  }
}
