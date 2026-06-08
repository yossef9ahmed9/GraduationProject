namespace GraduationProject.Contracts.Location
{
    // NEW: response returned when reading a patient's current location.
    public record PatientLocationResponse(
        int PatientId,
        string PatientName,
        double? Latitude,
        double? Longitude,
        DateTime? LastLocationUpdate,
        bool IsInEmergency       // useful for the ambulance dashboard
    );

    // NEW: response returned when reading an ambulance's current location.
    // Returned to the patient's app so they can show the ambulance on a map.
    public record AmbulanceLocationResponse(
        int AmbulanceId,
        string DriverName,           // ← was StationName
        string AvailabilityStatus,
        double? Latitude,
        double? Longitude,
        DateTime? LastLocationUpdate,
        double? DistanceFromPatientKm
    );
}
