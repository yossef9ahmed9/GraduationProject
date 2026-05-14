namespace GraduationProject.Contracts.EmergencyDispatches
{
    // NEW FILE: request model for creating an emergency dispatch
    // used by POST /api/emergencydispatches
    public record EmergencyDispatchRequest(
        int PatientId,
        int AmbulanceId,
        double PatientLatitude,
        double PatientLongitude,
        string? Notes
    );
}
