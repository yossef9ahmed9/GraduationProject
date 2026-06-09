using GraduationProject.Contracts.EmergencyDispatches;
using GraduationProject.Entities;
using GraduationProject.Helpers;
using GraduationProject.Presistence;
using Mapster;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    public class AutoEmergencyService(
        AppDbContext context,
        INotificationService notificationService,
        IFcmService fcmService,
        ILogger<AutoEmergencyService> logger) : IAutoEmergencyService
    {
        private readonly AppDbContext _context = context;
        private readonly INotificationService _notificationService = notificationService;
        private readonly IFcmService _fcmService = fcmService;
        private readonly ILogger<AutoEmergencyService> _logger = logger;

        private const int HeartRateCriticalLow  = 40;
        private const int HeartRateCriticalHigh = 150;
        private const double OxygenSaturationCriticalLow = 90.0;
        private const int StaleLocationMinutes = 5; // ambulances not seen in 5 min are skipped

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

            // Block re-dispatch only if someone has already accepted (OnTheWay/Arrived)
            var alreadyActive = await _context.EmergencyDispatches
                .AnyAsync(d =>
                    d.PatientId == patient.Id &&
                    (d.Status == "OnTheWay" || d.Status == "Arrived"),
                    cancellationToken);

            if (alreadyActive)
                return null;

            await using var transaction = await _context.Database.BeginTransactionAsync(cancellationToken);

            // Find top 3 nearest available ambulances and send them all a request.
            // The first one to accept wins — the others get cancelled automatically.
            var ambulances = await FindNearestAmbulancesAsync(patient, 3, cancellationToken);

            if (!ambulances.Any())
            {
                vital.EmergencyStatus = true;
                await _context.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return null;
            }

            vital.EmergencyStatus = true;
            patient.IsInEmergency = true;

            var notes = BuildEmergencyNotes(vital);

            // Create a Pending dispatch for each candidate ambulance.
            // We do NOT set them Busy yet — they must accept first.
            EmergencyDispatch? firstDispatch = null;
            foreach (var ambulance in ambulances)
            {
                var dispatch = new EmergencyDispatch
                {
                    PatientId        = patient.Id,
                    AmbulanceId      = ambulance.Id,
                    DispatchedAt     = DateTime.UtcNow,
                    Status           = "Pending",
                    PatientLatitude  = patient.Latitude  ?? 0,
                    PatientLongitude = patient.Longitude ?? 0,
                    Notes            = notes
                };
                await _context.EmergencyDispatches.AddAsync(dispatch, cancellationToken);
                firstDispatch ??= dispatch;
            }

            await _context.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            try
            {
                await _notificationService.SendEmergencyAlertAsync(
                    new GraduationProject.Contracts.Notifications.EmergencyNotificationRequest(
                        patient.Id,
                        patient.Name,
                        notes,
                        $"{ambulances.Count} ambulance(s) notified"
                    ),
                    cancellationToken);

                await _fcmService.SendEmergencyPushAsync(
                    patient.Id, patient.Name, notes, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Failed to send emergency notification for patient {PatientId}",
                    patient.Id);
            }

            return firstDispatch?.Adapt<EmergencyDispatchResponse>();
        }

        private static bool IsCritical(VitalSigns v)
        {
            if (v.HeartRate <= HeartRateCriticalLow || v.HeartRate >= HeartRateCriticalHigh)
                return true;

            if (v.OxygenSaturation < OxygenSaturationCriticalLow)
                return true;

            return false;
        }

        private async Task<List<Ambulance>> FindNearestAmbulancesAsync(
            Patient patient,
            int count,
            CancellationToken cancellationToken)
        {
            var cutoff = DateTime.UtcNow.AddMinutes(-StaleLocationMinutes);

            var available = await _context.Ambulances
                .Where(a => a.AvailabilityStatus == "Available" &&
                            !a.IsDeleted &&
                            a.Latitude.HasValue &&
                            a.Longitude.HasValue &&
                            a.LastLocationUpdate.HasValue &&
                            a.LastLocationUpdate.Value >= cutoff)   // ← fresh GPS only
                .ToListAsync(cancellationToken);

            // Fallback: if no fresh ambulances found, accept any available ambulance
            // (covers edge case where GPS is slow to update on first login)
            if (!available.Any())
            {
                available = await _context.Ambulances
                    .Where(a => a.AvailabilityStatus == "Available" && !a.IsDeleted)
                    .ToListAsync(cancellationToken);
            }

            if (!available.Any())
                return [];

            if (!patient.Latitude.HasValue || !patient.Longitude.HasValue)
                return available.Take(count).ToList();

            return available
                .Where(a => a.Latitude.HasValue && a.Longitude.HasValue)
                .OrderBy(a => LocationHelper.HaversineDistance(
                    patient.Latitude.Value, patient.Longitude.Value,
                    a.Latitude!.Value, a.Longitude!.Value))
                .Take(count)
                .ToList()
                .Concat(available
                    .Where(a => !a.Latitude.HasValue || !a.Longitude.HasValue)
                    .Take(Math.Max(0, count - available.Count(a => a.Latitude.HasValue))))
                .Take(count)
                .ToList();
        }

        private static string BuildEmergencyNotes(VitalSigns v)
        {
            var alerts = new List<string>();

            if (v.HeartRate <= HeartRateCriticalLow)
                alerts.Add($"Critical low heart rate: {v.HeartRate} bpm");
            else if (v.HeartRate >= HeartRateCriticalHigh)
                alerts.Add($"Critical high heart rate: {v.HeartRate} bpm");

            if (v.OxygenSaturation < OxygenSaturationCriticalLow)
                alerts.Add($"Critical low oxygen saturation: {v.OxygenSaturation}%");

            return "[AUTO-EMERGENCY] " + string.Join(" | ", alerts);
        }
    }
}