namespace GraduationProject.Services
{
    /// <summary>
    /// Delivers transactional emails (password reset, emergency alerts, etc.).
    /// Register a concrete implementation such as SendGridEmailService or SmtpEmailService
    /// in DependencyInjection.cs and configure credentials via environment variables.
    /// </summary>
    public interface IEmailService
    {
        /// <summary>
        /// Sends a password-reset link to the given address.
        /// The token must be URL-encoded and embedded in a link pointing to your
        /// frontend reset page, e.g. https://yourapp.com/reset-password?token=...&amp;email=...
        /// </summary>
        Task SendPasswordResetEmailAsync(string toEmail, string resetToken);
    }
}
