namespace GraduationProject.Entities
{
    public class ChatMessage : ISoftDeletable
    {
        public int Id { get; set; }
        public string SenderEmail { get; set; } = string.Empty;
        public string SenderName { get; set; } = string.Empty;
        public string ReceiverEmail { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
        public DateTime SentAt { get; set; } = DateTime.UtcNow;
        public bool IsRead { get; set; } = false;
        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }

        // Per-user delete — only hides message for that user, not both
        public bool DeletedBySender   { get; set; } = false;
        public bool DeletedByReceiver { get; set; } = false;
    }
}
