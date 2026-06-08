import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:meditrack/theme/app_theme.dart';

// ── Interactive map picker ─────────────────────────────────────
// Opens as a bottom sheet. User taps the map to place a pin,
// or taps the location button to jump to their current GPS position.
// Returns a LatLng when the user presses "Confirm Location".

class MapLocationPicker extends StatefulWidget {
  final String title;
  final double? initialLat;
  final double? initialLng;

  const MapLocationPicker({
    super.key,
    this.title = 'Set Location',
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late MapController _mapCtrl;
  LatLng? _selected;
  bool _locating = false;

  static const LatLng _defaultCenter = LatLng(30.0444, 31.2357); // Cairo

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _selected = loc;
        _locating = false;
      });
      _mapCtrl.move(loc, 16);
    } catch (_) {
      setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgBase : AppColors.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Drag handle
        Center(
          child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(child: Text(widget.title,
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700))),
            IconButton(
              onPressed: _locating ? null : _goToCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 22),
              tooltip: 'My current location',
            ),
          ]),
        ),

        // Map
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _selected ?? _defaultCenter,
                initialZoom:   _selected != null ? 15 : 11,
                onTap: (_, loc) => setState(() => _selected = loc),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.meditrack',
                ),
                if (_selected != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _selected!,
                      width: 40, height: 40,
                      child: const Icon(Icons.location_pin,
                          color: Colors.red, size: 40),
                    ),
                  ]),
              ],
            ),

            // Coordinate overlay
            Positioned(
              top: 12, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selected != null
                        ? '${_selected!.latitude.toStringAsFixed(5)}, '
                          '${_selected!.longitude.toStringAsFixed(5)}'
                        : 'Tap the map to set location',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
            ),
          ]),
        ),

        // Buttons
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16,
              MediaQuery.of(context).viewPadding.bottom + 16),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              child: const Text('Confirm Location'),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Static location picker field ───────────────────────────────
// A tappable field that opens MapLocationPicker in a bottom sheet.
// Use for Doctor (clinic) and Lab (lab address) registration fields
// where the location is fixed, not live GPS.

class StaticLocationPickerField extends StatefulWidget {
  final String label;
  final double? initialLat;
  final double? initialLng;
  final void Function(double lat, double lng) onPicked;

  const StaticLocationPickerField({
    super.key,
    required this.label,
    required this.onPicked,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<StaticLocationPickerField> createState() =>
      _StaticLocationPickerFieldState();
}

class _StaticLocationPickerFieldState
    extends State<StaticLocationPickerField> {
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _lat = widget.initialLat;
    _lng = widget.initialLng;
  }

  Future<void> _openMap() async {
    final result = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapLocationPicker(
        title:      widget.label,
        initialLat: _lat,
        initialLng: _lng,
      ),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });
      widget.onPicked(result.latitude, result.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLoc = _lat != null && _lng != null;

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
        onTap: _openMap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasLoc
                  ? (isDark
                      ? AppColors.darkBadgeGreenTxt
                      : AppColors.badgeGreenTxt)
                      .withValues(alpha: 0.4)
                  : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
            ),
          ),
          child: Row(children: [
            Icon(
              hasLoc
                  ? Icons.location_on_rounded
                  : Icons.add_location_alt_outlined,
              size: 18,
              color: hasLoc
                  ? (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)
                  : (isDark ? AppColors.darkAccent : AppColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: hasLoc
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location set ✓',
                          style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkBadgeGreenTxt
                                : AppColors.badgeGreenTxt,
                          ),
                        ),
                        Text(
                          '${_lat!.toStringAsFixed(5)}, '
                          '${_lng!.toStringAsFixed(5)}',
                          style: GoogleFonts.dmMono(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Tap to open map and set location',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary,
                      ),
                    ),
            ),
            Icon(Icons.map_outlined, size: 16,
                color: isDark ? AppColors.darkAccent : AppColors.accent),
          ]),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }
}
