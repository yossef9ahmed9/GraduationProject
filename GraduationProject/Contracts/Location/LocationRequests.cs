namespace GraduationProject.Contracts.Location
{
    // NEW: request model for updating a patient's GPS location.
    // Called by the mobile app periodically (or on significant movement)
    // so the auto-emergency service always has a fresh patient position
    // when it needs to find the nearest ambulance.
    public record UpdatePatientLocationRequest(
        double Latitude,
        double Longitude
    );

    // NEW: request model for updating an ambulance's GPS location.
    // Called by the ambulance driver's app while on a dispatch
    // so the patient/frontend can track the ambulance in real time.
    public record UpdateAmbulanceLocationRequest(
        double Latitude,
        double Longitude
    );
}
