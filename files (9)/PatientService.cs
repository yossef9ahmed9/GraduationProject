namespace GraduationProject.Services
{
    public class PatientService(AppDbContext context) : IPatientService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<PatientResponse>> GetAllPatientsAsync(CancellationToken cancellationToken = default) =>
            await _context.Patients.AsNoTracking().ProjectToType<PatientResponse>().ToListAsync(cancellationToken);

        public async Task<Result<PatientResponse>> GetPatientAsync(int id, CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients.FindAsync(id, cancellationToken);
            return patient == null
                ? Result.Failure<PatientResponse?>(PatientErrors.PatientNotFound)
                : Result.Success(patient.Adapt<PatientResponse>());
        }

        public async Task<Result<PatientResponse>> AddPatientAsync(PatientRequest request, CancellationToken cancellationToken = default)
        {
            var exists = await _context.Patients
                .AnyAsync(p => p.Email == request.Email, cancellationToken);

            if (exists)
                return Result.Failure<PatientResponse>(PatientErrors.DuplicatedPatient);

            var newPatient = request.Adapt<Patient>();
            newPatient.Gender = request.Gender.ToLower();

            await _context.Patients.AddAsync(newPatient, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(newPatient.Adapt<PatientResponse>());
        }

        public async Task<Result> UpdatePatientAsync(int id, PatientRequest request, CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients.FindAsync(id, cancellationToken);

            if (patient == null)
                return Result.Failure(PatientErrors.PatientNotFound);

            var exists = await _context.Patients
                .AnyAsync(p => (p.Email == request.Email) && p.Id != id, cancellationToken);

            if (exists)
                return Result.Failure(PatientErrors.DuplicatedPatient);

            request.Adapt(patient);

            // Normalize gender after Adapt overwrites it
            patient.Gender = request.Gender.ToLower();

            // FIXED: BloodType, ChronicDiseases, Allergies are now part of PatientRequest
            // so Mapster's Adapt() above will copy them automatically. No manual assignment needed.
            // (Mapster maps same-name properties by default.)

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeletePatientAsync(int id, CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients.FindAsync(id, cancellationToken);
            if (patient == null)
                return Result.Failure(PatientErrors.PatientNotFound);

            patient.IsDeleted = true;
            patient.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
    }
}
