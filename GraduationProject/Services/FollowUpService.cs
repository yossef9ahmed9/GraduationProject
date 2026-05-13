using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Services
{
    public class FollowUpService(AppDbContext context) : IFollowUpService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<FollowUpResponse>> GetAllAsync(CancellationToken cancellationToken = default)
        {
            return await _context.FollowUps
                .AsNoTracking()
                .ProjectToType<FollowUpResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<FollowUpResponse>> AddAsync(FollowUpRequest request, CancellationToken cancellationToken = default)
        {
            var followUp = request.Adapt<FollowUp>();

            await _context.FollowUps.AddAsync(followUp, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(followUp.Adapt<FollowUpResponse>());
        }
        public async Task<IEnumerable<FollowUpResponse>> GetByDoctorAsync(
             int doctorId, CancellationToken cancellationToken = default)
        {
            return await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.DoctorId == doctorId)
                .ProjectToType<FollowUpResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<IEnumerable<FollowUpResponse>> GetByPatientAsync(
            int patientId, CancellationToken cancellationToken = default)
        {
            return await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.PatientId == patientId)
                .ProjectToType<FollowUpResponse>()
                .ToListAsync(cancellationToken);
        }
    }
}