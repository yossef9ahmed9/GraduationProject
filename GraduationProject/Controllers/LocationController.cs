using System.Security.Claims;
using GraduationProject.Contracts.Location;
using GraduationProject.Presistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Controllers
{
    // NEW CONTROLLER: handles all real-time location updates and reads.
    //
    // Endpoints:
    //   PATCH /api/location/patient/{patientId}        — patient updates their GPS
    //   GET   /api/location/patient/{patientId}        — read a patient's last known location
    //   PATCH /api/location/ambulance/{ambulanceId}    — ambulance updates their GPS
    //   GET   /api/location/ambulance/{ambulanceId}    — read an ambulance's last known location
    //   GET   /api/location/dispatch/{dispatchId}/ambulance — track the ambulance on an active dispatch
    //   GET   /api/location/ambulances/nearest?lat=&lng= — find nearest available ambulances to any point

    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class LocationController(AppDbContext context) : ControllerBase
    {
        private readonly AppDbContext _context = context;

        // ── PUT /api/location/patient/{patientId} ─────────────────────────────
        // Called by the patient's mobile app to push their current GPS position.
        // Should be called every 30-60 seconds while the app is in the foreground,
        // or immediately when an emergency is detected.
        // The auto-emergency service reads these coordinates when dispatching.
        [HttpPut("patient/{patientId}")]
        public async Task<IActionResult> UpdatePatientLocation(
            int patientId,
            [FromBody] UpdatePatientLocationRequest request,
            CancellationToken cancellationToken)
        {
            var patient = await _context.Patients
                .FindAsync(new object[] { patientId }, cancellationToken);

            if (patient is null)
                return NotFound(new { message = "Patient not found." });

            // NEW: stamp the new coordinates and the update time
            patient.Latitude           = request.Latitude;
            patient.Longitude          = request.Longitude;
            patient.LastLocationUpdate = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            return Ok(new PatientLocationResponse(
                patient.Id,
                patient.Name,
                patient.Latitude,
                patient.Longitude,
                patient.LastLocationUpdate,
                patient.IsInEmergency
            ));
        }

        // ── GET /api/location/patient/{patientId} ─────────────────────────────
        // Returns the patient's last known GPS position.
        // Used by the doctor/ambulance dashboards.
        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetPatientLocation(
            int patientId,
            CancellationToken cancellationToken)
        {
            var patient = await _context.Patients
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == patientId, cancellationToken);

            if (patient is null)
                return NotFound(new { message = "Patient not found." });

            return Ok(new PatientLocationResponse(
                patient.Id,
                patient.Name,
                patient.Latitude,
                patient.Longitude,
                patient.LastLocationUpdate,
                patient.IsInEmergency
            ));
        }

        // ── PUT /api/location/ambulance/{ambulanceId} ─────────────────────────
        // Called by the ambulance driver's app to push their current GPS position.
        // Should be called every 10-15 seconds while on an active dispatch so the
        // patient can see the ambulance moving toward them on a map.
        [HttpPut("ambulance/{ambulanceId}")]
        public async Task<IActionResult> UpdateAmbulanceLocation(
            int ambulanceId,
            [FromBody] UpdateAmbulanceLocationRequest request,
            CancellationToken cancellationToken)
        {
            var ambulance = await _context.Ambulances
                .FindAsync(new object[] { ambulanceId }, cancellationToken);

            if (ambulance is null)
                return NotFound(new { message = "Ambulance not found." });

            // NEW: stamp the new coordinates and the update time
            ambulance.Latitude           = request.Latitude;
            ambulance.Longitude          = request.Longitude;
            ambulance.LastLocationUpdate = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            return Ok(new AmbulanceLocationResponse(
                ambulance.Id,
                ambulance.StationName,
                ambulance.AvailabilityStatus,
                ambulance.Latitude,
                ambulance.Longitude,
                ambulance.LastLocationUpdate,
                DistanceFromPatientKm: null   // no patient context here
            ));
        }

        // ── GET /api/location/ambulance/{ambulanceId} ─────────────────────────
        // Returns the ambulance's last known GPS position.
        [HttpGet("ambulance/{ambulanceId}")]
        public async Task<IActionResult> GetAmbulanceLocation(
            int ambulanceId,
            CancellationToken cancellationToken)
        {
            var ambulance = await _context.Ambulances
                .AsNoTracking()
                .FirstOrDefaultAsync(a => a.Id == ambulanceId, cancellationToken);

            if (ambulance is null)
                return NotFound(new { message = "Ambulance not found." });

            return Ok(new AmbulanceLocationResponse(
                ambulance.Id,
                ambulance.StationName,
                ambulance.AvailabilityStatus,
                ambulance.Latitude,
                ambulance.Longitude,
                ambulance.LastLocationUpdate,
                DistanceFromPatientKm: null
            ));
        }

        // ── GET /api/location/dispatch/{dispatchId}/ambulance ─────────────────
        // THE KEY TRACKING ENDPOINT.
        // The patient's app calls this repeatedly (every 10-15 seconds) to get the
        // live position of the ambulance coming to them, plus the distance remaining.
        // Returns both the ambulance location AND the calculated distance from the
        // patient so the app can display "Ambulance is 2.3 km away".
        [HttpGet("dispatch/{dispatchId}/ambulance")]
        public async Task<IActionResult> TrackDispatchAmbulance(
            int dispatchId,
            CancellationToken cancellationToken)
        {
            // NEW: load dispatch with both ambulance and patient for distance calc
            var dispatch = await _context.EmergencyDispatches
                .AsNoTracking()
                .Include(d => d.Ambulance)
                .Include(d => d.Patient)
                .FirstOrDefaultAsync(d => d.Id == dispatchId, cancellationToken);

            if (dispatch is null)
                return NotFound(new { message = "Dispatch not found." });

            var ambulance = dispatch.Ambulance;
            var patient   = dispatch.Patient;

            // NEW: calculate current distance between ambulance and patient
            // using Haversine — same formula as AutoEmergencyService
            double? distance = null;

            if (ambulance.Latitude.HasValue  && ambulance.Longitude.HasValue &&
                patient.Latitude.HasValue    && patient.Longitude.HasValue)
            {
                distance = HaversineDistance(
                    patient.Latitude.Value,   patient.Longitude.Value,
                    ambulance.Latitude.Value, ambulance.Longitude.Value);

                // round to 2 decimal places for cleaner display
                distance = Math.Round(distance.Value, 2);
            }

            return Ok(new AmbulanceLocationResponse(
                ambulance.Id,
                ambulance.StationName,
                ambulance.AvailabilityStatus,
                ambulance.Latitude,
                ambulance.Longitude,
                ambulance.LastLocationUpdate,
                DistanceFromPatientKm: distance
            ));
        }

        // ── GET /api/location/ambulances/nearest?lat=&lng=&count= ────────────
        // Returns the N nearest available ambulances to a given coordinate.
        // Useful for admin dashboards, manual dispatch UIs, or showing coverage.
        // Default count = 5.
        [HttpGet("ambulances/nearest")]
        public async Task<IActionResult> GetNearestAmbulances(
            [FromQuery] double lat,
            [FromQuery] double lng,
            [FromQuery] int count = 5,
            CancellationToken cancellationToken = default)
        {
            var available = await _context.Ambulances
                .AsNoTracking()
                .Where(a => a.AvailabilityStatus == "Available")
                .ToListAsync(cancellationToken);

            if (!available.Any())
                return Ok(new List<AmbulanceLocationResponse>());

            var withGps = available
                .Where(a => a.Latitude.HasValue && a.Longitude.HasValue)
                .OrderBy(a => HaversineDistance(lat, lng, a.Latitude!.Value, a.Longitude!.Value))
                .Take(count)
                .Select(a => new AmbulanceLocationResponse(
                    a.Id, a.StationName, a.AvailabilityStatus,
                    a.Latitude, a.Longitude, a.LastLocationUpdate,
                    DistanceFromPatientKm: Math.Round(HaversineDistance(
                        lat, lng, a.Latitude!.Value, a.Longitude!.Value), 2)))
                .ToList();

            var remaining = count - withGps.Count;
            if (remaining > 0)
            {
                var withoutGps = available
                    .Where(a => !a.Latitude.HasValue || !a.Longitude.HasValue)
                    .Take(remaining)
                    .Select(a => new AmbulanceLocationResponse(
                        a.Id, a.StationName, a.AvailabilityStatus,
                        a.Latitude, a.Longitude, a.LastLocationUpdate,
                        DistanceFromPatientKm: null))
                    .ToList();

                withGps.AddRange(withoutGps);
            }

            var nearest = withGps;

            return Ok(nearest);
        }

        // ── Haversine helper ──────────────────────────────────────────────────
        // NEW: duplicated here (also in AutoEmergencyService) to keep both classes
        // self-contained. If you want to share it, extract to a static LocationHelper
        // class in a Helpers/ folder and reference it from both places.
        private static double HaversineDistance(
            double lat1, double lon1,
            double lat2, double lon2)
        {
            const double R = 6371.0; // Earth radius in km

            var dLat = ToRad(lat2 - lat1);
            var dLon = ToRad(lon2 - lon1);

            var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                    Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) *
                    Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return R * c;
        }

        private static double ToRad(double degrees) => degrees * (Math.PI / 180.0);
    }
}
