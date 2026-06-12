namespace GraduationProject.Contracts.Ratings
{
    /// <summary>
    /// Submitted by a patient to rate a doctor or a lab.
    /// Exactly one of DoctorId / LabId must be provided.
    /// </summary>
    public record RatingRequest(
        double Stars,
        int?   DoctorId = null,
        int?   LabId    = null
    );
}
