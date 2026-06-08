namespace GraduationProject.Contracts.Ambulances
{
    // DriverName is the primary display name (shown in Fleet card and status bar)
    public record AmbulanceResponse(
        int       Id,
        string    Email,
        string    DriverName,          // ← primary display name
        string    DriverPhone,
        string    LicensePlate,
        string    Phone,               // ambulance unit phone
        string    AvailabilityStatus,
        string?   ServiceArea,         // optional zone label
        double?   Latitude,
        double?   Longitude,
        DateTime? LastLocationUpdate,
        int       ActiveDispatchCount
    );

    public record AmbulanceDispatchSummary(
        int       Id,
        DateTime  DispatchedAt,
        DateTime? ArrivedAt,
        DateTime? ResolvedAt,
        string    Status,
        int       PatientId,
        string    PatientName,
        string?   Notes
    );

    public record UpdateAmbulanceAvailabilityRequest(
        string AvailabilityStatus  // Available / Busy / NotAvailable
    );

    // Location update — sent from ambulance app periodically
    public record UpdateAmbulanceLocationRequest(
        double Latitude,
        double Longitude
    );
}
