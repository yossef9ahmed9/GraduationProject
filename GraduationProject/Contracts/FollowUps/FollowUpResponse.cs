namespace GraduationProject.Contracts.FollowUps
{
    public record FollowUpResponse(
        int Id,
        string Diagnosis,
        string TreatmentPlan,
        string Notes,
        DateTime LastUpdate,

        // UPDATED: NextVisitDate and Severity were added to the FollowUp entity
        // but never added here — so the frontend never received them
        // nullable because older records won't have a next visit date set
        DateTime? NextVisitDate,
        string Severity,

        int PatientId,
        int DoctorId
    );
}
