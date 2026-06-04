namespace GraduationProject.Services
{
    public class PatientService(AppDbContext context) : IPatientService
    {
        private readonly AppDbContext _context = context;

        public async Task<PagedResponse<PatientResponse>> GetAllPatientsAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default) =>
            await _context.Patients
                .AsNoTracking()
                .OrderBy(p => p.Id)
                .ProjectToType<PatientResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);

        public async Task<Result<PatientResponse?>> GetPatientAsync(
            int id, CancellationToken cancellationToken = default)
        {
            // FIXED: was FindAsync(id, cancellationToken) which passes the token as
            // a key argument. Correct overload is FindAsync(object[], CancellationToken).
            var patient = await _context.Patients
                .FindAsync(new object[] { id }, cancellationToken);

            return patient == null
                ? Result.Failure<PatientResponse?>(PatientErrors.PatientNotFound)
                : Result.Success<PatientResponse?>(patient.Adapt<PatientResponse>());
        }

        public async Task<Result<PatientResponse>> AddPatientAsync(
            PatientRequest request, CancellationToken cancellationToken = default)
        {
            var exists = await _context.Patients
                .AnyAsync(p => p.Email == request.Email, cancellationToken);

            if (exists)
                return Result.Failure<PatientResponse>(PatientErrors.DuplicatedPatient);

            var newPatient = request.Adapt<Patient>();

            // Normalize gender to lowercase — DB check constraint requires 'male'/'female'
            newPatient.Gender = request.Gender.ToLower();

            await _context.Patients.AddAsync(newPatient, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(newPatient.Adapt<PatientResponse>());
        }

        public async Task<Result> UpdatePatientAsync(
            int id, PatientRequest request, CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .FindAsync(new object[] { id }, cancellationToken);

            if (patient == null)
                return Result.Failure(PatientErrors.PatientNotFound);

            var exists = await _context.Patients
                .AnyAsync(p => p.Email == request.Email && p.Id != id, cancellationToken);

            if (exists)
                return Result.Failure(PatientErrors.DuplicatedPatient);

            request.Adapt(patient);
            patient.Gender = request.Gender.ToLower();

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeletePatientAsync(
            int id, CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .FindAsync(new object[] { id }, cancellationToken);

            if (patient == null)
                return Result.Failure(PatientErrors.PatientNotFound);

            patient.IsDeleted    = true;
            patient.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
