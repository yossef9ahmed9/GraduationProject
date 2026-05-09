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
    }
}