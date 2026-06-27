using GraduationProject.Contracts.EmergencyDispatches;
using GraduationProject.Contracts.HeartRisk;
using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public class VitalSignsService(
        AppDbContext context,
        IAutoEmergencyService autoEmergency,
        IHeartRiskService heartRiskService,
        IFcmService fcmService,
        ILogger<VitalSignsService> logger
        ) : IVitalSignsService
    {
        private readonly AppDbContext _context = context;
        private readonly IAutoEmergencyService _autoEmergency = autoEmergency;
        private readonly IHeartRiskService _heartRiskService = heartRiskService;
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

            // ── 1. حفظ الـ vital ──────────────────────────────────────────────────
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

            await _context.Entry(vital).Reference(v => v.Patient).LoadAsync(cancellationToken);
            var patient = vital.Patient;

            // ── 2. استشر الـ AI Model ─────────────────────────────────────────────
            HeartRiskResponse? aiResult = null;
            try
            {
                var age = patient.BirthDate != default
                    ? DateTime.Today.Year - patient.BirthDate.Year
                    : 40;
                var sex = patient.Gender?.ToLower() == "female" ? 0 : 1;

                var aiRes = await _heartRiskService.PredictAsync(
                    new HeartRiskRequest(
                        Bpm:   vital.HeartRate,
                        Spo2:  vital.OxygenSaturation,
                        HrvMs: 50.0,   // default — sensor doesn't send HRV yet
                        Age:   age,
                        Sex:   sex),
                    cancellationToken);

                if (aiRes.IsSuccess) aiResult = aiRes.Value;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "AI risk assessment unavailable for vital {VitalId}. Falling back to threshold rules.",
                    vital.Id);
            }

            // ── 3. قرار الـ tier ──────────────────────────────────────────────────
            // AI متاح → استخدمه | AI offline → fallback thresholds
            bool isCritical;
            bool isWarning;

            if (aiResult is not null)
            {
                isCritical = aiResult.Tier.Equals("CRITICAL", StringComparison.OrdinalIgnoreCase)
                          || aiResult.Alert;
                isWarning  = aiResult.Tier.Equals("WARNING",  StringComparison.OrdinalIgnoreCase)
                          && !isCritical;
            }
            else
            {
                // Fallback — same thresholds as AutoEmergencyService
                isCritical = vital.HeartRate >= 150 || vital.HeartRate <= 40
                          || vital.OxygenSaturation < 90.0;
                isWarning  = !isCritical &&
                             (vital.HeartRate > 110 || vital.HeartRate < 55
                           || vital.OxygenSaturation < 95.0);
            }

            // ── 4. كان في emergency وبقى Normal/Warning → auto-resolve ───────────
            if (patient.IsInEmergency && !isCritical)
            {
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

                // OnTheWay/Arrived → notify driver, don't cancel
                var activeDispatches = await _context.EmergencyDispatches
                    .Include(d => d.Ambulance)
                    .Where(d => d.PatientId == patient.Id &&
                                (d.Status == "OnTheWay" || d.Status == "Arrived"))
                    .ToListAsync(cancellationToken);

                foreach (var d in activeDispatches)
                {
                    if (d.Ambulance?.FcmToken != null)
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

                patient.IsInEmergency = false;
                vital.EmergencyStatus = false;
                await _context.SaveChangesAsync(cancellationToken);

                try
                {
                    await _fcmService.SendNormalVitalsPushAsync(
                        patient.Id, patient.Name,
                        $"HR: {vital.HeartRate} bpm | SpO₂: {vital.OxygenSaturation}%",
                        cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "Failed to send normal vitals notification for patient {PatientId}", patient.Id);
                }

                var resolvedResponse = vital.Adapt<VitalSignsResponse>() with { AutoDispatch = null };
                return Result.Success(resolvedResponse);
            }

            // ── 5. Warning → notification للدكتور والقريب بس (مش dispatch) ────────
            if (isWarning)
            {
                vital.EmergencyStatus = false;
                await _context.SaveChangesAsync(cancellationToken);

                try
                {
                    await _fcmService.SendWarningVitalsPushAsync(
                        patient.Id, patient.Name,
                        aiResult?.Action ?? $"HR: {vital.HeartRate} bpm | SpO₂: {vital.OxygenSaturation}%",
                        cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex,
                        "Failed to send warning notification for patient {PatientId}", patient.Id);
                }

                var warnResponse = vital.Adapt<VitalSignsResponse>() with { AutoDispatch = null };
                return Result.Success(warnResponse);
            }

            // ── 6. Critical → dispatch ────────────────────────────────────────────
            EmergencyDispatchResponse? autoDispatch = null;
            if (isCritical)
            {
                vital.EmergencyStatus = true;
                await _context.SaveChangesAsync(cancellationToken);

                try
                {
                    autoDispatch = await _autoEmergency.TryTriggerEmergencyAsync(
                        vital.Id, cancellationToken);
                }
                catch (OperationCanceledException) { throw; }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "Auto-emergency dispatch failed for vital {VitalId} / patient {PatientId}.",
                        vital.Id, vital.PatientId);
                }
            }

            var response = vital.Adapt<VitalSignsResponse>() with { AutoDispatch = autoDispatch };
            return Result.Success(response);
        }
    }
}
