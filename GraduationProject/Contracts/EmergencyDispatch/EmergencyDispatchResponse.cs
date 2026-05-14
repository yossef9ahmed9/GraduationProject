namespace GraduationProject.Contracts.EmergencyDispatches
{
    // NEW FILE: response model returned from all emergency dispatch endpoints
    // mirrors the EmergencyDispatch entity fields that are safe to expose
    public record EmergencyDispatchResponse(
        int Id,
        DateTime DispatchedAt,
        DateTime? ArrivedAt,      // null until ambulance marks arrival
        DateTime? ResolvedAt,     // null until case is closed
        string Status,            // Pending / OnTheWay / Arrived / Resolved / Cancelled
        double PatientLatitude,
        double PatientLongitude,
        string? Notes,
        int PatientId,
        int AmbulanceId
    );
}
