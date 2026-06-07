namespace GraduationProject.Services
{
    public class PatientService(AppDbContext context) : IPatientService
    {
        private readonly AppDbContext _context = context;

        // Fetch ProfilePictureUrl for a set of emails in one query, in-memory lookup
        private async Task<Dictionary<string, string?>> GetPicMapAsync(
            IEnumerable<string> emails, CancellationToken ct) =>
            await _context.Users
                .AsNoTracking()
                .Where(u => emails.Contains(u.Email!))
                .Select(u => new { u.Email, u.ProfilePictureUrl })
                .ToDictionaryAsync(u => u.Email!, u => u.ProfilePictureUrl, ct);

        public async Task<PagedResponse<PatientResponse>> GetAllPatientsAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            var totalCount = await _context.Patients.CountAsync(cancellationToken);

            var patients = await _context.Patients
                .AsNoTracking()
                .OrderBy(p => p.Id)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            var picMap = await GetPicMapAsync(patients.Select(p => p.Email), cancellationToken);

            var items = patients.Select(p => p.Adapt<PatientResponse>() with
            {
                ProfilePictureUrl = picMap.GetValueOrDefault(p.Email)
            }).ToList();

            var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);
            return new PagedResponse<PatientResponse>(
                items, pageNumber, pageSize, totalCount,
                totalPages, pageNumber > 1, pageNumber < totalPages);
        }

        public async Task<Result<PatientResponse?>> GetPatientAsync(
            int id, CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .AsNoTracking()
                .Where(p => p.Id == id)
                .FirstOrDefaultAsync(cancellationToken);

            if (patient == null)
                return Result.Failure<PatientResponse?>(PatientErrors.PatientNotFound);

            var picMap = await GetPicMapAsync([patient.Email], cancellationToken);
            var response = patient.Adapt<PatientResponse>() with
            {
                ProfilePictureUrl = picMap.GetValueOrDefault(patient.Email)
            };
            return Result.Success<PatientResponse?>(response);
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

        public async Task<Result> UpdateBloodTypeAsync(
             int id, string bloodType,
             CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .FindAsync(new object[] { id }, cancellationToken);

            if (patient is null)
                return Result.Failure(PatientErrors.PatientNotFound);

            var valid = new[] { "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-" };
            if (!valid.Contains(bloodType))
                return Result.Failure(new Error(
                    "Patient.InvalidBloodType",
                    "Blood type must be one of: A+, A-, B+, B-, AB+, AB-, O+, O-",
                    StatusCodes.Status400BadRequest));

            patient.BloodType = bloodType;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
