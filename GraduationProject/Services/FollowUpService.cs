using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Services
{
    public class FollowUpService(AppDbContext context) : IFollowUpService
    {
        private readonly AppDbContext _context = context;

        public async Task<PagedResponse<FollowUpResponse>> GetAllAsync(int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return await _context.FollowUps
                .AsNoTracking()
                .ProjectToType<FollowUpResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<Result<FollowUpResponse>> GetAsync(int id, CancellationToken cancellationToken = default)
        {
            var followUp = await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.Id == id)
                .ProjectToType<FollowUpResponse>()
                .FirstOrDefaultAsync(cancellationToken);

            return followUp is null
                ? Result.Failure<FollowUpResponse>(FollowUpErrors.FollowUpNotFound)
                : Result.Success(followUp);
        }

        public async Task<PagedResponse<FollowUpResponse>> GetByPatientAsync(int patientId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.PatientId == patientId)
                .ProjectToType<FollowUpResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<PagedResponse<FollowUpResponse>> GetByDoctorAsync(int doctorId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.DoctorId == doctorId)
                .ProjectToType<FollowUpResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<Result<FollowUpResponse>> AddAsync(FollowUpRequest request, CancellationToken cancellationToken = default)
        {
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure<FollowUpResponse>(FollowUpErrors.PatientNotFound);

            var doctorExists = await _context.Doctors
                .AnyAsync(d => d.Id == request.DoctorId, cancellationToken);

            if (!doctorExists)
                return Result.Failure<FollowUpResponse>(FollowUpErrors.DoctorNotFound);

            var followUp = request.Adapt<FollowUp>();

            await _context.FollowUps.AddAsync(followUp, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(followUp.Adapt<FollowUpResponse>());
        }
        public async Task<Result> UpdateAsync(int id, FollowUpRequest request, CancellationToken cancellationToken = default)
        {
            var followUp = await _context.FollowUps.FindAsync(new object[] { id }, cancellationToken);

            if (followUp is null)
                return Result.Failure(FollowUpErrors.FollowUpNotFound);

            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return Result.Failure(FollowUpErrors.PatientNotFound);

            var doctorExists = await _context.Doctors
                .AnyAsync(d => d.Id == request.DoctorId, cancellationToken);

            if (!doctorExists)
                return Result.Failure(FollowUpErrors.DoctorNotFound);

            request.Adapt(followUp);
            followUp.LastUpdate = DateTime.UtcNow;

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default)
        {
            var followUp = await _context.FollowUps.FindAsync(new object[] { id }, cancellationToken);

            if (followUp is null)
                return Result.Failure(FollowUpErrors.FollowUpNotFound);

            followUp.IsDeleted = true;
            followUp.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
