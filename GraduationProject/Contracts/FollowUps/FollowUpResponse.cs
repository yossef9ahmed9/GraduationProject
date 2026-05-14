namespace GraduationProject.Contracts.FollowUps
{
    public record FollowUpResponse(
        int Id,
        string Diagnosis,
        string TreatmentPlan,
        string Notes,
        DateTime LastUpdate,
        string Severity,
        DateTime? NextVisitDate,
        int PatientId,
        int DoctorId
    );
}
