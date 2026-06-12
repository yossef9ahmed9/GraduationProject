namespace GraduationProject.Contracts.Ratings
{
    public record RatingResponse(
        int    Id,
        int    PatientId,
        int?   DoctorId,
        int?   LabId,
        double Stars,
        DateTime UpdatedAtUtc
    );

    /// <summary>
    /// Aggregate rating summary returned inside Doctor / Lab responses.
    /// </summary>
    public record RatingSummary(
        double AverageRating,
        int    RatingCount
    );
}
