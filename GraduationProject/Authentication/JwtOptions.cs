namespace GraduationProject.Authentication
{
    // NEW: strongly typed config class
    // maps to the "Jwt" section in appsettings.json
    public class JwtOptions
    {
        // the section name in appsettings.json
        public static string SectionName = "Jwt";

        public string Key { get; set; } = string.Empty;
        public string Issuer { get; set; } = string.Empty;
        public string Audience { get; set; } = string.Empty;
        public int ExpiryMinutes { get; set; }
        public int RefreshTokenExpiryDays { get; set; }
    }
}