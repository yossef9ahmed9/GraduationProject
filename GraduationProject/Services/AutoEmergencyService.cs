using GraduationProject.Contracts.EmergencyDispatches;
using GraduationProject.Entities;
using GraduationProject.Presistence;
using Mapster;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    // NEW: automatically dispatches the nearest available ambulance
    // when a patient's vital signs are critically abnormal.
    // Triggered internally by VitalSignsService — never called directly from a controller.
    public class AutoEmergencyService(AppDbContext context) : IAutoEmergencyService
    {
        private readonly AppDbContext _context = context;

        // ── Thresholds ────────────────────────────────────────────────────────────
        // These are the hard limits that classify a reading as a critical emergency.
        // Adjust values here without touching any other file.

        private const int HeartRateCriticalLow  = 40;   // bpm — severe bradycardia
        private const int HeartRateCriticalHigh = 150;  // bpm — severe tachycardia

        private const double OxygenSaturationCriticalLow = 90.0; // % — hypoxia

        private const double TemperatureCriticalLow  = 35.0; // °C — hypothermia
        private const double TemperatureCriticalHigh = 39.5; // °C — hyperpyrexia

        private const int BloodPressureSystolicCriticalHigh = 180; // mmHg — hypertensive crisis
        private const int BloodPressureSystolicCriticalLow  = 80;  // mmHg — hypotensive shock

        private const int RespiratoryRateCriticalLow  = 8;  // breaths/min — respiratory depression
        private const int RespiratoryRateCriticalHigh = 30; // breaths/min — respiratory distress

        private const double BloodGlucoseCriticalLow  = 3.0;  // mmol/L — severe hypoglycaemia
        private const double BloodGlucoseCriticalHigh = 16.7; // mmol/L — hyperglycaemic crisis

        // ─────────────────────────────────────────────────────────────────────────

        public async Task<EmergencyDispatchResponse?> TryTriggerEmergencyAsync(
            int vitalSignsId,
            CancellationToken cancellationToken = default)
        {
            // ── 1. Load the vital signs record with its patient ───────────────────
            var vital = await _context.VitalSigns
                .Include(v => v.Patient)
                .FirstOrDefaultAsync(v => v.Id == vitalSignsId, cancellationToken);

            if (vital == null)
                return null;

            var patient = vital.Patient;

            // ── 2. Check whether any value is critically abnormal ─────────────────
            if (!IsCritical(vital))
                return null;

            // ── 3. Guard: do not dispatch again if patient is already in emergency ─
            // IsInEmergency is set to true when we dispatch and cleared when resolved.
            if (patient.IsInEmergency)
                return null;

            // Also check for any active (non-resolved, non-cancelled) dispatch
            // as a second guard in case IsInEmergency was not cleared properly.
            var alreadyActive = await _context.EmergencyDispatches
                .AnyAsync(d =>
                    d.PatientId == patient.Id &&
                    d.Status != "Resolved" &&
                    d.Status != "Cancelled",
                    cancellationToken);

            if (alreadyActive)
                return null;

            // ── 4. Find the nearest available ambulance ───────────────────────────
            var ambulance = await FindNearestAmbulanceAsync(patient, cancellationToken);

            if (ambulance == null)
            {
                // NEW: mark the vital reading as an emergency even if no ambulance
                // is available yet, so the flag is visible in dashboards.
                vital.EmergencyStatus = true;
                await _context.SaveChangesAsync(cancellationToken);
                return null; // nothing more we can do right now
            }

            // ── 5. Mark the vital reading as emergency ────────────────────────────
            vital.EmergencyStatus = true;

            // ── 6. Mark the patient as being in an active emergency ───────────────
            patient.IsInEmergency = true;

            // ── 7. Mark the ambulance as busy so it won't be double-dispatched ────
            ambulance.AvailabilityStatus = "Busy";

            // ── 8. Build the notes string with the abnormal readings ──────────────
            var notes = BuildEmergencyNotes(vital);

            // ── 9. Create the EmergencyDispatch record ────────────────────────────
            var dispatch = new EmergencyDispatch
            {
                PatientId    = patient.Id,
                AmbulanceId  = ambulance.Id,
                DispatchedAt = DateTime.UtcNow,
                Status       = "Pending",
                // Use the patient's last known GPS coordinates.
                // If the patient has no location on file, default to 0,0
                // (the caller/frontend can update via a separate endpoint).
                PatientLatitude  = patient.Latitude  ?? 0,
                PatientLongitude = patient.Longitude ?? 0,
                Notes = notes
            };

            await _context.EmergencyDispatches.AddAsync(dispatch, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return dispatch.Adapt<EmergencyDispatchResponse>();
        }

        // ── Private helpers ───────────────────────────────────────────────────────

        // NEW: returns true when at least one vital value crosses a critical threshold.
        private static bool IsCritical(VitalSigns v)
        {
            // Heart rate
            if (v.HeartRate <= HeartRateCriticalLow || v.HeartRate >= HeartRateCriticalHigh)
                return true;

            // Oxygen saturation
            if (v.OxygenSaturation.HasValue && v.OxygenSaturation.Value < OxygenSaturationCriticalLow)
                return true;

            // Temperature
            if (v.Temperature.HasValue &&
                (v.Temperature.Value < TemperatureCriticalLow || v.Temperature.Value > TemperatureCriticalHigh))
                return true;

            // Systolic blood pressure
            if (v.BloodPressureSystolic.HasValue &&
                (v.BloodPressureSystolic.Value > BloodPressureSystolicCriticalHigh ||
                 v.BloodPressureSystolic.Value < BloodPressureSystolicCriticalLow))
                return true;

            // Respiratory rate
            if (v.RespiratoryRate.HasValue &&
                (v.RespiratoryRate.Value < RespiratoryRateCriticalLow ||
                 v.RespiratoryRate.Value > RespiratoryRateCriticalHigh))
                return true;

            // Blood glucose
            if (v.BloodGlucose.HasValue &&
                (v.BloodGlucose.Value < BloodGlucoseCriticalLow ||
                 v.BloodGlucose.Value > BloodGlucoseCriticalHigh))
                return true;

            return false;
        }

        // NEW: finds the closest ambulance with AvailabilityStatus == "Available".
        // Uses the Haversine formula when both the patient and the ambulance have GPS
        // coordinates. Falls back to any available ambulance when coordinates are missing.
        private async Task<Ambulance?> FindNearestAmbulanceAsync(
            Patient patient,
            CancellationToken cancellationToken)
        {
            var available = await _context.Ambulances
                .Where(a => a.AvailabilityStatus == "Available")
                .ToListAsync(cancellationToken);

            if (!available.Any())
                return null;

            // If patient has no GPS coordinates, just return the first available ambulance
            if (!patient.Latitude.HasValue || !patient.Longitude.HasValue)
                return available.First();

            // NEW: rank by straight-line distance using Haversine formula.
            // This is computed in memory (not SQL) because EF Core cannot translate
            // the Math.Sin/Math.Cos calls to SQL Server. The result set of available
            // ambulances is expected to be small (< 100), so this is fine.
            return available
                .OrderBy(a => HaversineDistance(
                    patient.Latitude.Value,
                    patient.Longitude.Value,
                    a.Latitude  ?? double.MaxValue,
                    a.Longitude ?? double.MaxValue))
                .First();
        }

        // NEW: Haversine formula — returns the great-circle distance in kilometres
        // between two GPS coordinates.
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

        // NEW: builds a human-readable summary of which values triggered the emergency.
        // Saved in the dispatch Notes field so paramedics know what to expect.
        private static string BuildEmergencyNotes(VitalSigns v)
        {
            var alerts = new List<string>();

            if (v.HeartRate <= HeartRateCriticalLow)
                alerts.Add($"Critical low heart rate: {v.HeartRate} bpm");
            else if (v.HeartRate >= HeartRateCriticalHigh)
                alerts.Add($"Critical high heart rate: {v.HeartRate} bpm");

            if (v.OxygenSaturation.HasValue && v.OxygenSaturation.Value < OxygenSaturationCriticalLow)
                alerts.Add($"Critical low oxygen saturation: {v.OxygenSaturation}%");

            if (v.Temperature.HasValue)
            {
                if (v.Temperature.Value < TemperatureCriticalLow)
                    alerts.Add($"Hypothermia: {v.Temperature}°C");
                else if (v.Temperature.Value > TemperatureCriticalHigh)
                    alerts.Add($"Hyperpyrexia: {v.Temperature}°C");
            }

            if (v.BloodPressureSystolic.HasValue)
            {
                if (v.BloodPressureSystolic.Value > BloodPressureSystolicCriticalHigh)
                    alerts.Add($"Hypertensive crisis: {v.BloodPressureSystolic} mmHg systolic");
                else if (v.BloodPressureSystolic.Value < BloodPressureSystolicCriticalLow)
                    alerts.Add($"Hypotensive shock: {v.BloodPressureSystolic} mmHg systolic");
            }

            if (v.RespiratoryRate.HasValue)
            {
                if (v.RespiratoryRate.Value < RespiratoryRateCriticalLow)
                    alerts.Add($"Respiratory depression: {v.RespiratoryRate} breaths/min");
                else if (v.RespiratoryRate.Value > RespiratoryRateCriticalHigh)
                    alerts.Add($"Respiratory distress: {v.RespiratoryRate} breaths/min");
            }

            if (v.BloodGlucose.HasValue)
            {
                if (v.BloodGlucose.Value < BloodGlucoseCriticalLow)
                    alerts.Add($"Severe hypoglycaemia: {v.BloodGlucose} mmol/L");
                else if (v.BloodGlucose.Value > BloodGlucoseCriticalHigh)
                    alerts.Add($"Hyperglycaemic crisis: {v.BloodGlucose} mmol/L");
            }

            // Prefix so paramedics can spot it instantly
            return "[AUTO-EMERGENCY] " + string.Join(" | ", alerts);
        }
    }
}
