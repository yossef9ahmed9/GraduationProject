using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public class VitalSignsService(AppDbContext context) : IVitalSignsService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<VitalSignsResponse>> GetAllAsync(
            CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                // NEW: include Patient so PatientName is available for mapping
                .Include(v => v.Patient)
                .ProjectToType<VitalSignsResponse>()
                .ToListAsync(cancellationToken);
        }

        // NEW: get all vitals for a specific patient directly
        public async Task<IEnumerable<VitalSignsResponse>> GetByPatientAsync(
            int patientId,
            CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                .Where(v => v.PatientId == patientId)
                .Include(v => v.Patient)
                .OrderByDescending(v => v.TimeStamp) // newest first
                .ProjectToType<VitalSignsResponse>()
                .ToListAsync(cancellationToken);
        }

        // NEW: get only the latest vital reading for a patient
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
            // NEW: verify the patient exists before saving
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure<VitalSignsResponse>(VitalSignsErrors.PatientNotFound);

            // NEW: verify the sensor belongs to this patient for data integrity
            var sensorBelongsToPatient = await _context.Sensors
                .AnyAsync(s => s.Id == request.SensorId &&
                               s.PatientId == request.PatientId, cancellationToken);

            if (!sensorBelongsToPatient)
                return Result.Failure<VitalSignsResponse>(VitalSignsErrors.SensorNotBelongToPatient);

            var vital = request.Adapt<VitalSigns>();

            await _context.VitalSigns.AddAsync(vital, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            // NEW: reload with Patient included so response has PatientName
            await _context.Entry(vital)
                .Reference(v => v.Patient)
                .LoadAsync(cancellationToken);

            return Result.Success(vital.Adapt<VitalSignsResponse>());
        }
    }
}