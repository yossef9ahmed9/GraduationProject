using GraduationProject.Contracts.Labs;

namespace GraduationProject.Services
{
    public class LabService(AppDbContext context) : ILabService
    {
        private readonly AppDbContext _context = context;

        private async Task<Dictionary<string, string?>> GetPicMapAsync(
            IEnumerable<string> emails, CancellationToken ct) =>
            await _context.Users
                .AsNoTracking()
                .Where(u => emails.Contains(u.Email!))
                .Select(u => new { u.Email, u.ProfilePictureUrl })
                .ToDictionaryAsync(u => u.Email!, u => u.ProfilePictureUrl, ct);

        // Fetch average rating + count for a list of lab ids
        private async Task<Dictionary<int, (double avg, int count)>> GetRatingMapAsync(
            IEnumerable<int> labIds, CancellationToken ct) =>
            (await _context.Ratings
                .AsNoTracking()
                .Where(r => r.LabId.HasValue && labIds.Contains(r.LabId!.Value))
                .GroupBy(r => r.LabId!.Value)
                .Select(g => new { LabId = g.Key, Avg = g.Average(r => r.Stars), Count = g.Count() })
                .ToListAsync(ct))
            .ToDictionary(x => x.LabId, x => (x.Avg, x.Count));

        public async Task<PagedResponse<LabResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            var totalCount = await _context.Labs.CountAsync(cancellationToken);

            var labs = await _context.Labs
                .AsNoTracking()
                .OrderBy(l => l.Id)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            var picMap    = await GetPicMapAsync(labs.Select(l => l.Email), cancellationToken);
            var ratingMap = await GetRatingMapAsync(labs.Select(l => l.Id), cancellationToken);

            var items = labs.Select(l =>
            {
                var (avg, count) = ratingMap.GetValueOrDefault(l.Id, (0, 0));
                return l.Adapt<LabResponse>() with
                {
                    ProfilePictureUrl = picMap.GetValueOrDefault(l.Email),
                    AverageRating     = Math.Round(avg, 1),
                    RatingCount       = count,
                };
            }).ToList();

            var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);
            return new PagedResponse<LabResponse>(
                items, pageNumber, pageSize, totalCount,
                totalPages, pageNumber > 1, pageNumber < totalPages);
        }

        public async Task<Result<LabResponse>> GetAsync(int id,
            CancellationToken cancellationToken = default)
        {
            var lab = await _context.Labs
                .AsNoTracking()
                .Where(l => l.Id == id)
                .FirstOrDefaultAsync(cancellationToken);

            if (lab is null)
                return Result.Failure<LabResponse>(LabErrors.LabNotFound);

            var picMap    = await GetPicMapAsync([lab.Email], cancellationToken);
            var ratingMap = await GetRatingMapAsync([lab.Id], cancellationToken);
            var (avg, count) = ratingMap.GetValueOrDefault(lab.Id, (0, 0));

            var response = lab.Adapt<LabResponse>() with
            {
                ProfilePictureUrl = picMap.GetValueOrDefault(lab.Email),
                AverageRating     = Math.Round(avg, 1),
                RatingCount       = count,
            };
            return Result.Success(response);
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

            lab.IsDeleted = true;
            lab.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}
