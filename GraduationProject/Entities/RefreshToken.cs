namespace GraduationProject.Entities
{
    public class RefreshToken
    {
        public int Id { get; set; }

        public string Token { get; set; } = string.Empty;

        public DateTime ExpiresOn { get; set; }

        public DateTime CreatedOn { get; set; }

        public DateTime? RevokedOn { get; set; }

        public string UserId { get; set; } = string.Empty;

        public ApplicationUser User { get; set; } = default!;

        public bool IsExpired => DateTime.UtcNow >= ExpiresOn;

        public bool IsActive => RevokedOn == null && !IsExpired;
    }
}