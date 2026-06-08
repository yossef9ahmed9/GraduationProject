import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meditrack/theme/app_theme.dart';

// ════════════════════════════════════════════════════════════════
// LocationPickerField
// One tap to fetch the device's current GPS coordinates.
// Used for: clinic location, lab location, patient location,
//           service area (ambulance).
//
// Usage:
//   LocationPickerField(
//     label: 'Clinic Location',
//     initialLat: _lat, initialLng: _lng,
//     onPicked: (lat, lng) { setState(() { _lat = lat; _lng = lng; }); },
//   )
//
// pubspec.yaml dependency (already present):
//   geolocator: ^12.0.0
//
// AndroidManifest.xml permissions (added automatically by geolocator):
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
// ════════════════════════════════════════════════════════════════

class LocationPickerField extends StatefulWidget {
  final String label;
  final double? initialLat;
  final double? initialLng;
  final void Function(double lat, double lng) onPicked;

  const LocationPickerField({
    super.key,
    required this.label,
    required this.onPicked,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  double? _lat;
  double? _lng;
  bool    _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
  }

  Future<void> _pick() async {
    setState(() { _loading = true; _error = null; });
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _loading = false;
          _error = 'Location permission denied. Enable it in Settings.';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat     = pos.latitude;
        _lng     = pos.longitude;
        _loading = false;
      });
      widget.onPicked(pos.latitude, pos.longitude);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not get location. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final hasLoc  = _lat != null && _lng != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        widget.label.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          letterSpacing: 0.05,
        ),
      ),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: _loading ? null : _pick,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasLoc
                  ? (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)
                      .withValues(alpha: 0.4)
                  : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
            ),
          ),
          child: Row(children: [
            if (_loading)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                hasLoc ? Icons.location_on_rounded : Icons.location_searching_rounded,
                size: 18,
                color: hasLoc
                    ? (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)
                    : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: _loading
                  ? Text(
                      'Getting your location…',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                    )
                  : hasLoc
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            'Location set ✓',
                            style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                            style: GoogleFonts.dmMono(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                            ),
                          ),
                        ])
                      : Text(
                          'Tap to use current location',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                          ),
                        ),
            ),
            if (!_loading)
              Icon(
                Icons.my_location_rounded,
                size: 16,
                color: isDark ? AppColors.darkAccent : AppColors.accent,
              ),
          ]),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 4),
        Text(
          _error!,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
          ),
        ),
      ],
      const SizedBox(height: 12),
    ]);
  }
}
