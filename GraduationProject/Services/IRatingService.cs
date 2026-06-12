using GraduationProject.Contracts.Ratings;

namespace GraduationProject.Services
{
    public interface IRatingService
    {
        /// <summary>Submit or update a rating (patient-scoped via JWT email).</summary>
        Task<Result<RatingResponse>> SubmitAsync(
            string patientEmail,
            RatingRequest request,
            CancellationToken cancellationToken = default);

        /// <summary>Get the current patient's rating for a specific doctor or lab.</summary>
        Task<Result<RatingResponse>> GetMyRatingAsync(
            string patientEmail,
            int? doctorId,
            int? labId,
            CancellationToken cancellationToken = default);
    }
}
