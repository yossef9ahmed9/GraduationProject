using GraduationProject.Contracts.Notifications;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    public class NotificationService(
        AppDbContext context,
        ILogger<NotificationService> logger,
        IEmailService emailService) : INotificationService
    {
        private readonly AppDbContext _context = context;
        private readonly ILogger<NotificationService> _logger = logger;
        private readonly IEmailService _emailService = emailService;

        public async Task SendEmergencyAlertAsync(
            EmergencyNotificationRequest notification,
            CancellationToken cancellationToken = default)
        {
            _logger.LogInformation(
                "EMERGENCY ALERT — Patient {PatientId} ({PatientName}): {Notes}. Ambulance: {AmbulanceInfo}",
                notification.PatientId,
                notification.PatientName,
                notification.Notes,
                notification.AmbulanceInfo);

            // Notify primary relatives via email
            var relatives = await _context.Relatives
                .Where(r => r.PatientId == notification.PatientId
                         && r.IsPrimaryContact
                         && r.Email != null)
                .ToListAsync(cancellationToken);

            foreach (var relative in relatives)
            {
                try
                {
                    var subject = $"EMERGENCY — {notification.PatientName} needs immediate help";
                    var body = $@"
                        <h2>Emergency Alert</h2>
                        <p><strong>Patient:</strong> {notification.PatientName}</p>
                        <p><strong>Details:</strong> {notification.Notes}</p>
                        <p><strong>Ambulance:</strong> {notification.AmbulanceInfo}</p>
                        <p>Please contact the patient or wait for updates.</p>";

                    // Use the existing email service to deliver the alert
                    // This uses the same SMTP config as password reset emails
                    await _emailService.SendEmailAsync(
                        relative.Email, subject, body);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "Failed to send emergency email to relative {Email} for patient {PatientId}",
                        relative.Email, notification.PatientId);
                }
            }

            if (!relatives.Any())
            {
                _logger.LogWarning(
                    "No primary relatives with email found for patient {PatientId}. Notification was logged only.",
                    notification.PatientId);
            }
        }
    }
}
