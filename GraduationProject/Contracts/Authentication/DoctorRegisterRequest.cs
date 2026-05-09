namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated request model for doctor registration only
    // replaces the old giant RegisterRequest for the doctor role
    public record DoctorRegisterRequest
    (
        string FullName,
        string Email,
        string Password,
        string ConfirmPassword,

        // doctor-specific fields — all required, no nullables
        string Phone,
        string Specialization
    );
}