using GraduationProject.Contracts.MedicalTests;

namespace GraduationProject.Services
{
    public class MedicalTestService(AppDbContext context) : IMedicalTestService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<MedicalTestResponse>> GetAllAsync(CancellationToken cancellationToken = default)
        {
            return await _context.MedicalTests
                .AsNoTracking()
                .ProjectToType<MedicalTestResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<MedicalTestResponse>> GetAsync(int id, CancellationToken cancellationToken = default)
        {
            var test = await _context.MedicalTests
                .AsNoTracking()
                .Where(t => t.Id == id)
                .ProjectToType<MedicalTestResponse>()
                .FirstOrDefaultAsync(cancellationToken);

            return test is null
                ? Result.Failure<MedicalTestResponse>(MedicalTestErrors.MedicalTestNotFound)
                : Result.Success(test);
        }

        public async Task<IEnumerable<MedicalTestResponse>> GetByPatientAsync(int patientId, CancellationToken cancellationToken = default)
        {
            return await _context.MedicalTests
                .AsNoTracking()
                .Where(t => t.PatientId == patientId)
                .ProjectToType<MedicalTestResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<IEnumerable<MedicalTestResponse>> GetByLabAsync(int labId, CancellationToken cancellationToken = default)
        {
            return await _context.MedicalTests
                .AsNoTracking()
                .Where(t => t.LabId == labId)
                .ProjectToType<MedicalTestResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<MedicalTestResponse>> AddAsync(MedicalTestRequest request, CancellationToken cancellationToken = default)
        {
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure<MedicalTestResponse>(MedicalTestErrors.PatientNotFound);

            var labExists = await _context.Labs
                .AnyAsync(l => l.Id == request.LabId, cancellationToken);

            if (!labExists)
                return Result.Failure<MedicalTestResponse>(MedicalTestErrors.LabNotFound);

            var test = request.Adapt<MedicalTest>();

            await _context.MedicalTests.AddAsync(test, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(test.Adapt<MedicalTestResponse>());
        }

        public async Task<Result> UpdateAsync(int id, MedicalTestRequest request, CancellationToken cancellationToken = default)
        {
            var test = await _context.MedicalTests.FindAsync(new object[] { id }, cancellationToken);

            if (test is null)
                return Result.Failure(MedicalTestErrors.MedicalTestNotFound);

            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure(MedicalTestErrors.PatientNotFound);

            var labExists = await _context.Labs
                .AnyAsync(l => l.Id == request.LabId, cancellationToken);

            if (!labExists)
                return Result.Failure(MedicalTestErrors.LabNotFound);

            request.Adapt(test);

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default)
        {
            var test = await _context.MedicalTests.FindAsync(new object[] { id }, cancellationToken);

            if (test is null)
                return Result.Failure(MedicalTestErrors.MedicalTestNotFound);

            test.IsDeleted = true;
            test.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
