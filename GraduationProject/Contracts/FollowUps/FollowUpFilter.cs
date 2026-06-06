namespace GraduationProject.Contracts.FollowUps
{
    public record FollowUpFilter(
        int? PatientId = null,
        int? DoctorId = null,
        string? Severity = null,
        DateTime? From = null,
        DateTime? To = null,
        int PageNumber = 1,
        int PageSize = 50
    );
}
