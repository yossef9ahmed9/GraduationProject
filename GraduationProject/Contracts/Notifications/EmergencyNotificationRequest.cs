namespace GraduationProject.Contracts.Notifications
{
    public record EmergencyNotificationRequest(
        int PatientId,
        string PatientName,
        string Notes,
        string AmbulanceInfo
    );
}
