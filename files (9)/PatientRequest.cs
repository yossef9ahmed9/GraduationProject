namespace GraduationProject.Contracts.Patients
{
    public record PatientRequest(
        string Name,
        string Gender,
        string Phone,
        string Email,
        string Address,
        DateOnly BirthDate,
        string MedicalRecord,

        // FIXED: these three fields existed on the Patient entity but were missing
        // from PatientRequest, so PUT /api/patients/{id} silently ignored them.
        // BloodType has a default so existing callers don't break.
        string BloodType = "Unknown",
        string? ChronicDiseases = null,
        string? Allergies = null
    );
}
