namespace GraduationProject.Contracts.Authentication
{
    // FIXED: LicensePlate, DriverName, DriverPhone were nullable with empty-string
    // fallbacks in AuthService, meaning every registered ambulance had no driver info.
    // They are now required non-nullable strings.
    public record AmbulanceRegisterRequest(
        string Email,
        string Password,
        string ConfirmPassword,
        string StationName,
        string Phone,
        string AvailabilityStatus,
        string LicensePlate,
        string DriverName,
        string DriverPhone
    );
}
