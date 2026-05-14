namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated request model for ambulance registration only
    // replaces the old giant RegisterRequest for the ambulance role
    public record AmbulanceRegisterRequest(
        string Email,
        string Password,
        string ConfirmPassword,
        string StationName,
        string Phone,
        string AvailabilityStatus,
        string? LicensePlate = null,
        string? DriverName = null,
        string? DriverPhone = null
    );
}