namespace GraduationProject.Services
{
    public interface IEmailService
    {
        Task SendPasswordResetEmailAsync(string toEmail, string resetToken);
        Task SendEmailAsync(string toEmail, string subject, string body);
    }
}
