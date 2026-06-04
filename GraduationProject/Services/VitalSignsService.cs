using GraduationProject.Contracts.EmergencyDispatches;
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

        public async Task<PagedResponse<VitalSignsResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                .Include(v => v.Patient)
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
                .Where(v => v.PatientId == patientId)
                .Include(v => v.Patient)
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

            // Reload with Patient included so PatientName is available in the response
            await _context.Entry(vital)
                .Reference(v => v.Patient)
                .LoadAsync(cancellationToken);

            // ── Auto-emergency check ───────────────────────────────────────────
            // FIXED: the dispatch result was previously discarded, so AutoDispatch in
            // the response was always null even when an ambulance was dispatched.
            // We now capture it and include it in the response.
            EmergencyDispatchResponse? autoDispatch = null;
            try
            {
                autoDispatch = await _autoEmergency.TryTriggerEmergencyAsync(
                    vital.Id, cancellationToken);
            }
            catch (OperationCanceledException)
            {
                // Request was cancelled — re-throw so ASP.NET Core handles it cleanly
                throw;
            }
            catch (Exception ex)
            {
                // Vital reading is already saved — do not fail the whole request.
                // Log with both IDs so ops can manually review and re-dispatch if needed.
                _logger.LogError(ex,
                    "Auto-emergency dispatch failed for vital signs {VitalId} / patient {PatientId}. Manual review required.",
                    vital.Id, vital.PatientId);
            }
            // ── End auto-emergency check ───────────────────────────────────────

            // FIXED: use `with` to inject the real AutoDispatch value.
            // Mapster always maps AutoDispatch to null (by design in MappingConfigurations)
            // so a plain Adapt() would lose the dispatch info.
            var response = vital.Adapt<VitalSignsResponse>() with { AutoDispatch = autoDispatch };

            return Result.Success(response);
        }
    }
}
