namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated request model for lab registration only
    // replaces the old giant RegisterRequest for the lab role
    public record LabRegisterRequest
    (
        string Email,
        string Password,
        string ConfirmPassword,

        // lab-specific fields — all required, no nullables
        string LabName,
        string Location,
        string Phone
    );
}