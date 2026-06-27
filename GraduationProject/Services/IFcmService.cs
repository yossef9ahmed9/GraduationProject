namespace GraduationProject.Services
{
    public interface IFcmService
    {
        Task SendPushAsync(string fcmToken, string title, string body,
            Dictionary<string, string>? data = null,
            CancellationToken cancellationToken = default);

        Task SendEmergencyPushAsync(int patientId, string patientName,
            string notes, CancellationToken cancellationToken = default);

        Task SendNormalVitalsPushAsync(int patientId, string patientName,
            string details, CancellationToken cancellationToken = default);

        Task SendWarningVitalsPushAsync(int patientId, string patientName,
            string detail, CancellationToken cancellationToken = default);

        Task RegisterFcmTokenAsync(string userId, string fcmToken,
            CancellationToken cancellationToken = default);
    }
}
