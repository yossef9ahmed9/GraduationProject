import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meditrack/theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════
// SHARED WIDGETS & HELPERS — used by DoctorsPage and LabsPage
// ════════════════════════════════════════════════════════════════

// ── Sort mode ─────────────────────────────────────────────────
enum ProviderSortMode { name, rating, distance }

// ── Haversine distance ────────────────────────────────────────
double providerDistKm(
    double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) *
          sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;

// ── Sort bar ──────────────────────────────────────────────────
class ProviderSortBar extends StatelessWidget {
  final ProviderSortMode current;
  final void Function(ProviderSortMode) onChange;
  const ProviderSortBar({super.key, required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Sort:', style: GoogleFonts.dmSans(fontSize: 12,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
      const SizedBox(width: 6),
      ProviderSortChip(
          label: 'Name',
          icon: Icons.sort_by_alpha_rounded,
          selected: current == ProviderSortMode.name,
          onTap: () => onChange(ProviderSortMode.name)),
      const SizedBox(width: 4),
      ProviderSortChip(
          label: 'Rating',
          icon: Icons.star_rounded,
          selected: current == ProviderSortMode.rating,
          onTap: () => onChange(ProviderSortMode.rating)),
      const SizedBox(width: 4),
      ProviderSortChip(
          label: 'Near',
          icon: Icons.near_me_rounded,
          selected: current == ProviderSortMode.distance,
          onTap: () => onChange(ProviderSortMode.distance)),
    ]);
  }
}

class ProviderSortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const ProviderSortChip({
    super.key,
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? accent
                : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12,
              color: selected
                  ? accent
                  : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? accent
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
        ]),
      ),
    );
  }
}

// ── Rating dialog ─────────────────────────────────────────────
class ProviderRatingDialog extends StatefulWidget {
  final String name, subtitle;
  final double? initial;
  const ProviderRatingDialog({
    super.key,
    required this.name, required this.subtitle, this.initial,
  });

  @override
  State<ProviderRatingDialog> createState() => _ProviderRatingDialogState();
}

class _ProviderRatingDialogState extends State<ProviderRatingDialog> {
  late double _stars;

  @override
  void initState() {
    super.initState();
    _stars = widget.initial ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppColors.darkBgCard : AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Rate', style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(widget.name,
              style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          if (widget.subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(widget.subtitle, style: GoogleFonts.dmSans(fontSize: 13,
                color: isDark ? AppColors.darkAccent : AppColors.accent)),
          ],
          const SizedBox(height: 20),
          // Star row — tap to select
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return GestureDetector(
                onTap: () => setState(() => _stars = (i + 1).toDouble()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 36,
                    color: filled
                        ? const Color(0xFFFFC107)
                        : (isDark
                            ? AppColors.darkBorderColor
                            : AppColors.borderColor),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _stars == 0 ? 'Tap a star to rate'
                : _stars <= 1 ? 'Poor'
                : _stars <= 2 ? 'Fair'
                : _stars <= 3 ? 'Good'
                : _stars <= 4 ? 'Very Good'
                : 'Excellent',
            style: GoogleFonts.dmSans(fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _stars == 0
                  ? null
                  : () => Navigator.of(context).pop(_stars),
              child: const Text('Submit'),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────
class ProviderFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ProviderFilterChip({
    super.key,
    required this.label, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.darkAccent : AppColors.accent)
              : (isDark ? AppColors.darkBgCard : AppColors.bgCard),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
      ),
    );
  }
}

// ── Read-only star row ────────────────────────────────────────
class ProviderStarRow extends StatelessWidget {
  final double? rating;
  final double size;
  const ProviderStarRow({super.key, this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating != null && i < rating!;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: filled
              ? const Color(0xFFFFC107)
              : Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorderColor
                  : AppColors.borderColor,
        );
      }),
    );
  }
}

// ── Action button ─────────────────────────────────────────────
class ProviderActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  const ProviderActionBtn({
    super.key,
    required this.icon, required this.label,
    required this.onTap, this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? const Color(0xFFFFC107) : null;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: highlight ? const BorderSide(color: Color(0xFFFFC107)) : null,
      ),
    );
  }
}
