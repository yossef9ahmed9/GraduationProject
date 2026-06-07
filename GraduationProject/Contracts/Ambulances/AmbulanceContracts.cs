namespace GraduationProject.Contracts.Ambulances
{
    public record AmbulanceResponse(
        int       Id,
        string    Email,
        string    StationName,
        string    Phone,
        string    AvailabilityStatus,
        string    LicensePlate,
        string    DriverName,
        string    DriverPhone,
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
}
