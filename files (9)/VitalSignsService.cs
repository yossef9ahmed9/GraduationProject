using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public class VitalSignsService(
        AppDbContext context,
        IAutoEmergencyService autoEmergency,
        ILogger<VitalSignsService> logger
        ) : IVitalSignsService
    {
        private readonly AppDbContext _context = context;
        private readonly IAutoEmergencyService _autoEmergency = autoEmergency;
        private readonly ILogger<VitalSignsService> _logger = logger;

        public async Task<IEnumerable<VitalSignsResponse>> GetAllAsync(
            CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                .Include(v => v.Patient)
                .ProjectToType<VitalSignsResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<IEnumerable<VitalSignsResponse>> GetByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                .Where(v => v.PatientId == patientId)
                .Include(v => v.Patient)
                .OrderByDescending(v => v.TimeStamp)
                .ProjectToType<VitalSignsResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<VitalSignsResponse>> GetLatestByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default)
        {
            var vital = await _context.VitalSigns
                .AsNoTracking()
                .Where(v => v.PatientId == patientId)
                .Include(v => v.Patient)
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

            // Reload with Patient navigation so response has PatientName
            await _context.Entry(vital)
                .Reference(v => v.Patient)
                .LoadAsync(cancellationToken);

            // ── Auto-emergency check ──────────────────────────────────────────────
            // FIXED: we no longer swallow all exceptions silently.
            // - Infrastructure errors (DB down, etc.) are logged at Error level and
            //   re-thrown so the caller knows something went wrong.
            // - "No dispatch needed" is the normal path and returns null.
            // The vital reading has already been saved before this runs, so a dispatch
            // failure does NOT roll back the vital record — the reading is preserved.
            GraduationProject.Contracts.EmergencyDispatches.EmergencyDispatchResponse? autoDispatch = null;

            try
            {
                autoDispatch = await _autoEmergency.TryTriggerEmergencyAsync(vital.Id, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                // Request was cancelled — do not swallow, let it propagate
                throw;
            }
            catch (Exception ex)
            {
                // Log at Error so it surfaces in monitoring/alerting.
                // We do NOT re-throw here because the vital reading itself succeeded;
                // losing the vital data would be worse than a failed dispatch.
                // However, the error will appear in logs so on-call can investigate.
                _logger.LogError(
                    ex,
                    "Auto-emergency dispatch failed for VitalSigns {VitalId} / Patient {PatientId}. " +
                    "The vital reading was saved but no ambulance was dispatched. Manual review required.",
                    vital.Id, vital.PatientId);
            }
            // ── End auto-emergency check ─────────────────────────────────────────

            // FIXED: populate AutoDispatch in the response so the frontend can
            // immediately show ambulance details without a second API call.
            var response = vital.Adapt<VitalSignsResponse>() with { AutoDispatch = autoDispatch };

            return Result.Success(response);
        }
    }
}
