using GraduationProject.Contracts.Notifications;

namespace GraduationProject.Services
{
    public interface INotificationService
    {
        Task SendEmergencyAlertAsync(
            EmergencyNotificationRequest notification,
            CancellationToken cancellationToken = default);
        Task SendPushAsync(string fcmToken, string title, string body,
           Dictionary<string, string>? data = null, CancellationToken ct = default);
        Task RegisterFcmTokenAsync(string userId, string fcmToken, CancellationToken ct = default);
    }
}
