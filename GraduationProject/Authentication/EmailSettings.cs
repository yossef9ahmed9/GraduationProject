namespace GraduationProject.Authentication
{
    public class EmailSettings
    {
        public static string SectionName = "EmailSettings";

        public string SmtpHost    { get; set; } = string.Empty;
        public int    SmtpPort    { get; set; }
        public string SenderEmail { get; set; } = string.Empty;
        public string SenderName  { get; set; } = string.Empty;
        public string Password    { get; set; } = string.Empty;
    }
}
