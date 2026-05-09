using GraduationProject.Contracts.Labs;

namespace GraduationProject.Services
{
    public class LabService(AppDbContext context) : ILabService
    {
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<LabResponse>> GetAllAsync(CancellationToken cancellationToken = default)
        {
            return await _context.Labs
                .AsNoTracking()
                .ProjectToType<LabResponse>()
                .ToListAsync(cancellationToken);
        }

        public async Task<Result<LabResponse>> GetAsync(int id, CancellationToken cancellationToken = default)
        {
            var lab = await _context.Labs
                .AsNoTracking()
                .Where(l => l.Id == id)
                .ProjectToType<LabResponse>()
                .FirstOrDefaultAsync(cancellationToken);

            return lab is null
                ? Result.Failure<LabResponse>(LabErrors.LabNotFound)
                : Result.Success(lab);
        }

        public async Task<Result<LabResponse>> AddAsync(LabRequest request, CancellationToken cancellationToken = default)
        {
            var exists = await _context.Labs
                .AnyAsync(l => l.Name == request.Name, cancellationToken);

            if (exists)
                return Result.Failure<LabResponse>(LabErrors.DuplicatedLab);

            var lab = request.Adapt<Lab>();

            await _context.Labs.AddAsync(lab, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(lab.Adapt<LabResponse>());
        }

        public async Task<Result> UpdateAsync(int id, LabRequest request, CancellationToken cancellationToken = default)
        {
            var lab = await _context.Labs.FindAsync(new object[] { id }, cancellationToken);

            if (lab is null)
                return Result.Failure(LabErrors.LabNotFound);

            var exists = await _context.Labs
                .AnyAsync(l => l.Name == request.Name && l.Id != id, cancellationToken);

            if (exists)
                return Result.Failure(LabErrors.DuplicatedLab);

            request.Adapt(lab);

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default)
        {
            var lab = await _context.Labs.FindAsync(new object[] { id }, cancellationToken);

            if (lab is null)
                return Result.Failure(LabErrors.LabNotFound);

            _context.Labs.Remove(lab);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
