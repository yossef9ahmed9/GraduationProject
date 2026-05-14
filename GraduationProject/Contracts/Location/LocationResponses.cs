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
        string StationName,
        string AvailabilityStatus,
        double? Latitude,
        double? Longitude,
        DateTime? LastLocationUpdate,

        // NEW: straight-line distance in km from the patient to this ambulance.
        // Calculated server-side so the frontend doesn't need to implement Haversine.
        // Null when either party has no coordinates.
        double? DistanceFromPatientKm
    );
}
