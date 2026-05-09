namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated request model for patient registration only
    // replaces the old giant RegisterRequest for the patient role
    public record PatientRegisterRequest
    (
        string FullName,
        string Email,
        string Password,
        string ConfirmPassword,

        // patient-specific fields — all required, no nullables
        string Gender,
        string Phone,
        string Address,
        DateOnly BirthDate,
        string MedicalRecord
    );
}