using System.Net;
using System.Net.Mail;
using GraduationProject.Authentication;

namespace GraduationProject.Services
{
    public class EmailService(IOptions<EmailSettings> options, ILogger<EmailService> logger) : IEmailService
    {
        private readonly EmailSettings _settings = options.Value;
        private readonly ILogger<EmailService> _logger = logger;

        public async Task SendPasswordResetEmailAsync(string toEmail, string resetToken)
        {
            try
            {
                var subject = "Reset Your Password";

                // In a real deployment replace the token line with a deep link to your
                // frontend reset page. For now the raw token is included so callers can
                // POST directly to /api/auth/reset-password.
                var body = $"""
                    <h2>Password Reset Request</h2>
                    <p>You requested a password reset. Use the token below to reset your password.</p>
                    <p><strong>Reset Token:</strong></p>
                    <p style="background:#f4f4f4;padding:10px;font-family:monospace">{resetToken}</p>
                    <p>Call <code>POST /api/auth/reset-password</code> with your email, this token, and your new password.</p>
                    <p>This token expires after 1 hour.</p>
                    <p>If you did not request this, ignore this email.</p>
                    """;

                var message = new MailMessage
                {
                    From       = new MailAddress(_settings.SenderEmail, _settings.SenderName),
                    Subject    = subject,
                    Body       = body,
                    IsBodyHtml = true
                };

                message.To.Add(toEmail);

                using var client = new SmtpClient(_settings.SmtpHost, _settings.SmtpPort)
                {
                    Credentials = new NetworkCredential(_settings.SenderEmail, _settings.Password),
                    EnableSsl   = true
                };

                await client.SendMailAsync(message);
            }
            catch (Exception ex)
            {
                // Log but never expose SMTP errors to the caller —
                // the controller returns a generic message for security.
                _logger.LogError(ex, "Failed to send password reset email to {Email}", toEmail);
                throw;
            }
        }
    }
}
