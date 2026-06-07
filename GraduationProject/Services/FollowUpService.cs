using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Services
{
    public class FollowUpService(AppDbContext context) : IFollowUpService
    {
        private readonly AppDbContext _context = context;

        public async Task<PagedResponse<FollowUpResponse>> GetAllAsync(FollowUpFilter filter, CancellationToken cancellationToken = default)
        {
            var query = _context.FollowUps
                .AsNoTracking()
                .AsQueryable();

            if (filter.PatientId.HasValue)
                query = query.Where(f => f.PatientId == filter.PatientId.Value);

            if (filter.DoctorId.HasValue)
                query = query.Where(f => f.DoctorId == filter.DoctorId.Value);

            if (!string.IsNullOrWhiteSpace(filter.Severity))
                query = query.Where(f => f.Severity == filter.Severity);

            if (filter.From.HasValue)
                query = query.Where(f => f.LastUpdate >= filter.From.Value);

            if (filter.To.HasValue)
                query = query.Where(f => f.LastUpdate <= filter.To.Value);

            return await query
                .OrderByDescending(f => f.LastUpdate)
                .ThenByDescending(f => f.Id)
                .ProjectToType<FollowUpResponse>()
                .ToPagedListAsync(filter.PageNumber, filter.PageSize, cancellationToken);
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
                .OrderByDescending(f => f.LastUpdate)
                .ThenByDescending(f => f.Id)
                .ProjectToType<FollowUpResponse>()
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);
        }

        public async Task<PagedResponse<FollowUpResponse>> GetByDoctorAsync(int doctorId, int pageNumber = 1, int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.DoctorId == doctorId)
                .OrderByDescending(f => f.LastUpdate)
                .ThenByDescending(f => f.Id)
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
            followUp.LastUpdate = DateTime.UtcNow;

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

        public async Task<Result> SetStatusAsync(
            int id, string status, CancellationToken cancellationToken = default)
        {
            var followUp = await _context.FollowUps
                .FindAsync(new object[] { id }, cancellationToken);

            if (followUp is null)
                return Result.Failure(FollowUpErrors.FollowUpNotFound);

            followUp.Status     = status;
            followUp.LastUpdate = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }

        public async Task<Result> UpdatePrescriptionAsync(
            int id, string treatmentPlan, string notes,
            CancellationToken cancellationToken = default)
        {
            var followUp = await _context.FollowUps
                .FindAsync(new object[] { id }, cancellationToken);

            if (followUp is null)
                return Result.Failure(FollowUpErrors.FollowUpNotFound);

            if (!string.IsNullOrWhiteSpace(treatmentPlan))
                followUp.TreatmentPlan = treatmentPlan;

            if (!string.IsNullOrWhiteSpace(notes))
                followUp.Notes = notes;

            followUp.LastUpdate = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }
    }
}
