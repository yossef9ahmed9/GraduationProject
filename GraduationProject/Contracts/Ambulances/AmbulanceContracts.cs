namespace GraduationProject.Contracts.Ambulances
{
    // DriverName is the primary display name (shown in Fleet card and status bar)
    public record AmbulanceResponse(
        int       Id,
        string    Email,
        string    DriverName,
        string    DriverPhone,
        string    LicensePlate,
        string    Phone,
        string    AvailabilityStatus,
        string?   ServiceArea,
        double?   Latitude,
        double?   Longitude,
        DateTime? LastLocationUpdate,
        int       ActiveDispatchCount,
        string    LocationSource = "Unknown"  // "GPS" | "Manual" | "Unknown"
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
