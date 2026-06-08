namespace GraduationProject.Contracts.Authentication
{
    // StationName removed — DriverName is the display name now.
    // ServiceArea is optional (e.g. "Nasr City", "Shubra").
    public record AmbulanceRegisterRequest(
        string  Email,
        string  Password,
        string  ConfirmPassword,
        string  Phone,
        string  DriverName,
        string  DriverPhone,
        string  LicensePlate,
        string? ServiceArea = null      // optional zone label
    );
}
