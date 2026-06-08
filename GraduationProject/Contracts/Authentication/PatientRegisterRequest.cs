namespace GraduationProject.Contracts.Authentication
{
    public record PatientRegisterRequest(
        string   FullName,
        string   Email,
        string   Password,
        string   ConfirmPassword,
        string   Phone,
        string   Address,
        string   Gender,
        DateOnly BirthDate,
        string   BloodType,
        string?  MedicalRecord   = null,   // ← now optional
        string?  ChronicDiseases = null,
        string?  Allergies       = null
    );
}
