namespace GraduationProject.Contracts.FollowUps
{
    public record FollowUpRequest(
        string Diagnosis,
        string TreatmentPlan,
        string Notes,
        int PatientId,
        int DoctorId,
        string Severity = "Low",
        DateTime? NextVisitDate = null
    );
}