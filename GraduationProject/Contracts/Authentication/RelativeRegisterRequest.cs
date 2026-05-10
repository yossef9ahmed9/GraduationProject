namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated request model for relative registration only
    // replaces the old giant RegisterRequest for the relative role
    public record RelativeRegisterRequest
    (
        string FullName,
        string Email,
        string Password,
        string ConfirmPassword,

        // relative-specific fields — all required, no nullables
        string Phone,
        string RelationType,
        int PatientId
    );
}