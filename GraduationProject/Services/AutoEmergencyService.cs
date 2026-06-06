using GraduationProject.Contracts.EmergencyDispatches;
using GraduationProject.Entities;
using GraduationProject.Helpers;
using GraduationProject.Presistence;
using Mapster;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    public class AutoEmergencyService(
        AppDbContext context,
        INotificationService notificationService,
        ILogger<AutoEmergencyService> logger) : IAutoEmergencyService
    {
        private readonly AppDbContext _context = context;
        private readonly INotificationService _notificationService = notificationService;
        private readonly ILogger<AutoEmergencyService> _logger = logger;

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
            var vital = await _context.VitalSigns
                .Include(v => v.Patient)
                .FirstOrDefaultAsync(v => v.Id == vitalSignsId, cancellationToken);

            if (vital == null)
                return null;

            var patient = vital.Patient;

            if (!IsCritical(vital))
                return null;

            if (patient.IsInEmergency)
                return null;

            var alreadyActive = await _context.EmergencyDispatches
                .AnyAsync(d =>
                    d.PatientId == patient.Id &&
                    d.Status != "Resolved" &&
                    d.Status != "Cancelled",
                    cancellationToken);

            if (alreadyActive)
                return null;

            await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);

            var ambulance = await FindNearestAmbulanceAsync(patient, cancellationToken);

            if (ambulance == null)
            {
                vital.EmergencyStatus = true;
                await _context.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return null;
            }

            // Atomic claim: only succeeds if ambulance is still Available
            var rowsAffected = await _context.Ambulances
                .Where(a => a.Id == ambulance.Id && a.AvailabilityStatus == "Available")
                .ExecuteUpdateAsync(s => s.SetProperty(a => a.AvailabilityStatus, "Busy"),
                    cancellationToken);

            if (rowsAffected == 0)
            {
                // Lost the race — ambulance was taken by another request
                vital.EmergencyStatus = true;
                await _context.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return null;
            }

            ambulance = await _context.Ambulances
                .FindAsync(new object[] { ambulance.Id }, cancellationToken);

            vital.EmergencyStatus = true;
            patient.IsInEmergency = true;

            var notes = BuildEmergencyNotes(vital);

            var dispatch = new EmergencyDispatch
            {
                PatientId    = patient.Id,
                AmbulanceId  = ambulance.Id,
                DispatchedAt = DateTime.UtcNow,
                Status       = "Pending",
                PatientLatitude  = patient.Latitude  ?? 0,
                PatientLongitude = patient.Longitude ?? 0,
                Notes = notes
            };

            await _context.EmergencyDispatches.AddAsync(dispatch, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            try
            {
                await _notificationService.SendEmergencyAlertAsync(
                    new GraduationProject.Contracts.Notifications.EmergencyNotificationRequest(
                        patient.Id,
                        patient.Name,
                        notes,
                        $"{ambulance.StationName} ({ambulance.LicensePlate})"
                    ),
                    cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Failed to send emergency notification for patient {PatientId}",
                    patient.Id);
            }

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

            var withGps = available
                .Where(a => a.Latitude.HasValue && a.Longitude.HasValue)
                .OrderBy(a => LocationHelper.HaversineDistance(
                    patient.Latitude.Value, patient.Longitude.Value,
                    a.Latitude!.Value, a.Longitude!.Value))
                .ToList();

            return withGps.Count > 0 ? withGps.First() : available.First();
        }

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
