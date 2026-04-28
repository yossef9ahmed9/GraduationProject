namespace GraduationProject.Contracts.FollowUps
{
    public record FollowUpResponse(
        int Id,
        string Diagnosis,
        string TreatmentPlan,
        string Notes,
        DateTime LastUpdate,
        int PatientId,
        int DoctorId
    );
}