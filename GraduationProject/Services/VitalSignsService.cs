using GraduationProject.Contracts.EmergencyDispatches;
using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public class VitalSignsService(
        AppDbContext context,
        IAutoEmergencyService autoEmergency,
        IFcmService fcmService,
        ILogger<VitalSignsService> logger
        ) : IVitalSignsService
    {
        private readonly AppDbContext _context = context;
        private readonly IAutoEmergencyService _autoEmergency = autoEmergency;
        private readonly IFcmService _fcmService = fcmService;
        private readonly ILogger<VitalSignsService> _logger = logger;

        public async Task<PagedResponse<VitalSignsResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                .Include(v => v.Patient)
                .OrderBy(v => v.Id)
                .ProjectToType<VitalSignsResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<PagedResponse<VitalSignsResponse>> GetByPatientAsync(
            int patientId,
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                .Include(v => v.Patient)
                .Where(v => v.PatientId == patientId)
                .OrderByDescending(v => v.TimeStamp)
                .ProjectToType<VitalSignsResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<Result<VitalSignsResponse>> GetLatestByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default)
        {
            var vital = await _context.VitalSigns
                .AsNoTracking()
                .Include(v => v.Patient)
                .Where(v => v.PatientId == patientId)
                .OrderByDescending(v => v.TimeStamp)
                .FirstOrDefaultAsync(cancellationToken);

            return vital == null
                ? Result.Failure<VitalSignsResponse>(VitalSignsErrors.VitalSignsNotFound)
                : Result.Success(vital.Adapt<VitalSignsResponse>());
        }

        public async Task<Result<VitalSignsResponse>> AddAsync(
            VitalSignsRequest request,
            CancellationToken cancellationToken = default)
        {
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure<VitalSignsResponse>(VitalSignsErrors.PatientNotFound);

            var sensorBelongsToPatient = await _context.Sensors
                .AnyAsync(s => s.Id == request.SensorId &&
                               s.PatientId == request.PatientId, cancellationToken);

            if (!sensorBelongsToPatient)
                return Result.Failure<VitalSignsResponse>(VitalSignsErrors.SensorNotBelongToPatient);

            var vital = request.Adapt<VitalSigns>();

            await _context.VitalSigns.AddAsync(vital, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            var sensor = await _context.Sensors.FindAsync(
                new object[] { request.SensorId }, cancellationToken);
            if (sensor is not null)
            {
                sensor.LastPing = DateTime.UtcNow;
                sensor.IsActive = true;
                await _context.SaveChangesAsync(cancellationToken);
            }

            await _context.Entry(vital)
                .Reference(v => v.Patient)
                .LoadAsync(cancellationToken);

            var patient = vital.Patient;

            // ── Auto-resolve emergency if vitals are now normal ───────────────
            if (patient.IsInEmergency && !IsCritical(vital))
            {
                // Cancel all Pending dispatches — ambulance hasn't accepted yet
                var pendingDispatches = await _context.EmergencyDispatches
                    .Include(d => d.Ambulance)
                    .Where(d => d.PatientId == patient.Id && d.Status == "Pending")
                    .ToListAsync(cancellationToken);

                foreach (var d in pendingDispatches)
                {
                    d.Status = "Cancelled";
                    if (d.Ambulance != null)
                        d.Ambulance.AvailabilityStatus = "Available";
                }

                // OnTheWay / Arrived — don't cancel, just notify the driver
                var activeDispatches = await _context.EmergencyDispatches
                    .Include(d => d.Ambulance)
                    .Where(d => d.PatientId == patient.Id &&
                                (d.Status == "OnTheWay" || d.Status == "Arrived"))
                    .ToListAsync(cancellationToken);

                foreach (var d in activeDispatches)
                {
                    if (d.Ambulance?.FcmToken != null)
                    {
                        await _fcmService.SendPushAsync(
                            d.Ambulance.FcmToken,
                            "✅ Patient Vitals Normal",
                            $"{patient.Name} — vitals are now stable. Proceed at your discretion.",
                            new Dictionary<string, string>
                            {
                                ["patientId"] = patient.Id.ToString(),
                                ["type"]      = "normal_vitals",
                            },
                            cancellationToken);
                    }
                }

                patient.IsInEmergency = false;
                vital.EmergencyStatus = false;
                await _context.SaveChangesAsync(cancellationToken);

                // Notify doctors + relatives
                try
                {
                    await _fcmService.SendNormalVitalsPushAsync(
                        patient.Id,
                        patient.Name,
                        $"HR: {vital.HeartRate} bpm | SpO₂: {vital.OxygenSaturation}%",
                        cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to send normal vitals notification for patient {PatientId}", patient.Id);
                }

                var resolvedResponse = vital.Adapt<VitalSignsResponse>() with { AutoDispatch = null };
                return Result.Success(resolvedResponse);
            }

            EmergencyDispatchResponse? autoDispatch = null;
            try
            {
                autoDispatch = await _autoEmergency.TryTriggerEmergencyAsync(
                    vital.Id, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex,
                    "Auto-emergency dispatch failed for vital signs {VitalId} / patient {PatientId}. Manual review required.",
                    vital.Id, vital.PatientId);
            }

            var response = vital.Adapt<VitalSignsResponse>() with { AutoDispatch = autoDispatch };

            return Result.Success(response);
        }

        private static bool IsCritical(VitalSigns v)
        {
            if (v.HeartRate <= 40 || v.HeartRate >= 150) return true;
            if (v.OxygenSaturation < 90.0) return true;
            return false;
        }
    }
}