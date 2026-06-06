namespace GraduationProject.Contracts.Ambulances
{
    // ── Response ──────────────────────────────────────────────────────────────
    public record AmbulanceResponse(
        int      Id,
        string   Email,
        string   StationName,
        string   Phone,
        string   AvailabilityStatus,   // Available / Busy / OutOfService
        string   LicensePlate,
        string   DriverName,
        string   DriverPhone,
        double?  Latitude,
        double?  Longitude,
        DateTime? LastLocationUpdate,
        int      ActiveDispatchCount   // 0 when Available
    );

    // ── Requests ──────────────────────────────────────────────────────────────
    public record UpdateAmbulanceAvailabilityRequest(
        string AvailabilityStatus
    );
}
