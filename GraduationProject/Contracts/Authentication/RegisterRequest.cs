namespace GraduationProject.Contracts.Authentication
{
    public record RegisterRequest
    (
        // shared fields for all roles
        string FullName,
        string Email,
        string Password,
        string ConfirmPassword,
        string Role,

        // NEW: Patient specific fields (required only if Role = Patient)
        string? Gender,
        string? Phone,
        string? Address,
        DateOnly? BirthDate,
        string? MedicalRecord,

        // NEW: Doctor specific fields (required only if Role = Doctor)
        string? Specialization,

        // NEW: Lab specific fields (required only if Role = Lab)
        string? LabName,
        string? Location,

        // NEW: Relative specific fields (required only if Role = Relative)
        string? RelationType,
        int? PatientId,

        // NEW: Ambulance specific fields (required only if Role = Ambulance)
        string? StationName,
        string? AvailabilityStatus
    );
}