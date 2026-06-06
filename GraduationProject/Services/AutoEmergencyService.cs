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

            var rowsAffected = await _context.Ambulances
                .Where(a => a.Id == ambulance.Id && a.AvailabilityStatus == "Available")
                .ExecuteUpdateAsync(s => s.SetProperty(a => a.AvailabilityStatus, "Busy"),
                    cancellationToken);

            if (rowsAffected == 0)
            {
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
                PatientId        = patient.Id,
                AmbulanceId      = ambulance!.Id,
                DispatchedAt     = DateTime.UtcNow,
                Status           = "Pending",
                PatientLatitude  = patient.Latitude  ?? 0,
                PatientLongitude = patient.Longitude ?? 0,
                Notes            = notes
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

                await _fcmService.SendEmergencyPushAsync(
                    patient.Id, patient.Name, notes, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Failed to send emergency notification for patient {PatientId}",
                    patient.Id);
            }

            return dispatch.Adapt<EmergencyDispatchResponse>();
        }

        private static bool IsCritical(VitalSigns v)
        {
            if (v.HeartRate <= HeartRateCriticalLow || v.HeartRate >= HeartRateCriticalHigh)
                return true;

            if (v.OxygenSaturation < OxygenSaturationCriticalLow)
                return true;

            return false;
        }

        private async Task<Ambulance?> FindNearestAmbulanceAsync(
            Patient patient,
            CancellationToken cancellationToken)
        {
            var available = await _context.Ambulances
                .Where(a => a.AvailabilityStatus == "Available")
                .ToListAsync(cancellationToken);

            if (!available.Any())
                return null;

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