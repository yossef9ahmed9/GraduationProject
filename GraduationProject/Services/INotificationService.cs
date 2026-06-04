using GraduationProject.Contracts.Notifications;

namespace GraduationProject.Services
{
    public interface INotificationService
    {
        Task SendEmergencyAlertAsync(
            EmergencyNotificationRequest notification,
            CancellationToken cancellationToken = default);
    }
}
