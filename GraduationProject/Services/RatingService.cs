using GraduationProject.Contracts.Ratings;

namespace GraduationProject.Services
{
    public class RatingService(AppDbContext context) : IRatingService
    {
        private readonly AppDbContext _context = context;

        public async Task<Result<RatingResponse>> SubmitAsync(
            string patientEmail,
            RatingRequest request,
            CancellationToken cancellationToken = default)
        {
            // Validate stars
            if (request.Stars is < 1 or > 5)
                return Result.Failure<RatingResponse>(RatingErrors.InvalidStars);

            // Validate exactly one target
            if ((request.DoctorId.HasValue) == (request.LabId.HasValue))
                return Result.Failure<RatingResponse>(RatingErrors.InvalidTarget);

            // Resolve patient
            var patient = await _context.Patients
                .AsNoTracking()
                .Where(p => p.Email == patientEmail)
                .Select(p => new { p.Id })
                .FirstOrDefaultAsync(cancellationToken);

            if (patient is null)
                return Result.Failure<RatingResponse>(RatingErrors.PatientNotFound);

            // Upsert — find existing rating from this patient for this target
            var existing = await _context.Ratings
                .Where(r => r.PatientId == patient.Id
                         && r.DoctorId == request.DoctorId
                         && r.LabId    == request.LabId)
                .FirstOrDefaultAsync(cancellationToken);

            if (existing is not null)
            {
                existing.Stars        = request.Stars;
                existing.UpdatedAtUtc = DateTime.UtcNow;
            }
            else
            {
                existing = new Rating
                {
                    PatientId    = patient.Id,
                    DoctorId     = request.DoctorId,
                    LabId        = request.LabId,
                    Stars        = request.Stars,
                    CreatedAtUtc = DateTime.UtcNow,
                    UpdatedAtUtc = DateTime.UtcNow,
                };
                await _context.Ratings.AddAsync(existing, cancellationToken);
            }

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(new RatingResponse(
                existing.Id,
                existing.PatientId,
                existing.DoctorId,
                existing.LabId,
                existing.Stars,
                existing.UpdatedAtUtc));
        }

        public async Task<Result<RatingResponse>> GetMyRatingAsync(
            string patientEmail,
            int? doctorId,
            int? labId,
            CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .AsNoTracking()
                .Where(p => p.Email == patientEmail)
                .Select(p => new { p.Id })
                .FirstOrDefaultAsync(cancellationToken);

            if (patient is null)
                return Result.Failure<RatingResponse>(RatingErrors.PatientNotFound);

            var rating = await _context.Ratings
                .AsNoTracking()
                .Where(r => r.PatientId == patient.Id
                         && r.DoctorId  == doctorId
                         && r.LabId     == labId)
                .FirstOrDefaultAsync(cancellationToken);

            if (rating is null)
                return Result.Failure<RatingResponse>(
                    new Error("Rating.NotFound", "No rating found.", StatusCodes.Status404NotFound));

            return Result.Success(new RatingResponse(
                rating.Id,
                rating.PatientId,
                rating.DoctorId,
                rating.LabId,
                rating.Stars,
                rating.UpdatedAtUtc));
        }
    }
}
