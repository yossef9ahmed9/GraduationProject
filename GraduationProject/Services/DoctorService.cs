using GraduationProject.Contracts.Doctors;

namespace GraduationProject.Services
{
    public class DoctorService(AppDbContext context) : IDoctorService
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

        // Fetch average rating + count for a list of doctor ids
        private async Task<Dictionary<int, (double avg, int count)>> GetRatingMapAsync(
            IEnumerable<int> doctorIds, CancellationToken ct) =>
            (await _context.Ratings
                .AsNoTracking()
                .Where(r => r.DoctorId.HasValue && doctorIds.Contains(r.DoctorId!.Value))
                .GroupBy(r => r.DoctorId!.Value)
                .Select(g => new { DoctorId = g.Key, Avg = g.Average(r => r.Stars), Count = g.Count() })
                .ToListAsync(ct))
            .ToDictionary(x => x.DoctorId, x => (x.Avg, x.Count));

        public async Task<PagedResponse<DoctorResponse>> GetAllAsync(
            int pageNumber = 1, int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            var totalCount = await _context.Doctors.CountAsync(cancellationToken);

            var doctors = await _context.Doctors
                .AsNoTracking()
                .OrderBy(d => d.Id)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            var picMap    = await GetPicMapAsync(doctors.Select(d => d.Email), cancellationToken);
            var ratingMap = await GetRatingMapAsync(doctors.Select(d => d.Id), cancellationToken);

            var items = doctors.Select(d =>
            {
                var (avg, count) = ratingMap.GetValueOrDefault(d.Id, (0, 0));
                return d.Adapt<DoctorResponse>() with
                {
                    ProfilePictureUrl = picMap.GetValueOrDefault(d.Email),
                    AverageRating     = Math.Round(avg, 1),
                    RatingCount       = count,
                };
            }).ToList();

            var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);
            return new PagedResponse<DoctorResponse>(
                items, pageNumber, pageSize, totalCount,
                totalPages, pageNumber > 1, pageNumber < totalPages);
        }

        public async Task<Result<DoctorResponse>> GetAsync(int id,
            CancellationToken cancellationToken = default)
        {
            var doctor = await _context.Doctors
                .AsNoTracking()
                .Where(d => d.Id == id)
                .FirstOrDefaultAsync(cancellationToken);

            if (doctor == null)
                return Result.Failure<DoctorResponse>(DoctorErors.DoctorNotFound);

            var picMap    = await GetPicMapAsync([doctor.Email], cancellationToken);
            var ratingMap = await GetRatingMapAsync([doctor.Id], cancellationToken);
            var (avg, count) = ratingMap.GetValueOrDefault(doctor.Id, (0, 0));

            var response = doctor.Adapt<DoctorResponse>() with
            {
                ProfilePictureUrl = picMap.GetValueOrDefault(doctor.Email),
                AverageRating     = Math.Round(avg, 1),
                RatingCount       = count,
            };
            return Result.Success(response);
        }

        public async Task<Result<DoctorResponse>> AddAsync(DoctorRequest request, CancellationToken cancellationToken = default)
        {
            var exists = await _context.Doctors
                .AnyAsync(d => d.Email == request.Email, cancellationToken);

            if (exists)
                return Result.Failure<DoctorResponse>(DoctorErors.DuplicatedDoctor);

            var doctor = request.Adapt<Doctor>();

            await _context.Doctors.AddAsync(doctor, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(doctor.Adapt<DoctorResponse>());
        }

        public async Task<Result> UpdateAsync(int id,DoctorRequest request,CancellationToken cancellationToken = default)
        {
            var doctor = await _context.Doctors.FindAsync(new object[] { id }, cancellationToken);

            if (doctor == null)
                return Result.Failure(DoctorErors.DoctorNotFound);

            var exists = await _context.Doctors
                .AnyAsync(d => d.Email == request.Email && d.Id != id, cancellationToken);

            if (exists)
                return Result.Failure(DoctorErors.DuplicatedDoctor);

            request.Adapt(doctor);

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeleteAsync(int id, CancellationToken cancellationToken = default)
        {
            var doctor = await _context.Doctors.FindAsync(new object[] { id }, cancellationToken);

            if (doctor == null)
                return Result.Failure(DoctorErors.DoctorNotFound);

            doctor.IsDeleted = true;
            doctor.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }
    }
}