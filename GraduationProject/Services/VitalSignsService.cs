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
    }
}