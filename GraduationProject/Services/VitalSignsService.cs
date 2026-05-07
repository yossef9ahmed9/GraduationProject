using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Services
{
    public class VitalSignsService(AppDbContext context) : IVitalSignsService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<VitalSignsResponse>> GetAllAsync(CancellationToken cancellationToken = default)
        {
            return await _context.VitalSigns
                .AsNoTracking()
                .ProjectToType<VitalSignsResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<VitalSignsResponse>> AddAsync(VitalSignsRequest request, CancellationToken cancellationToken = default)
        {
            var vital = request.Adapt<VitalSigns>();

            await _context.VitalSigns.AddAsync(vital, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(vital.Adapt<VitalSignsResponse>());
        }
    }
}