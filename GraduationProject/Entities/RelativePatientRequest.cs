namespace GraduationProject.Entities
{
    public class RelativePatientRequest : ISoftDeletable
    {
        public int       Id         { get; set; }
        public int       RelativeId { get; set; }
        public int       PatientId  { get; set; }
        public string    Status     { get; set; } = "Pending"; // Pending | Approved | Rejected
        public DateTime  CreatedAt  { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt  { get; set; }

        public Relative Relative { get; set; } = default!;
        public Patient  Patient  { get; set; } = default!;

        public bool      IsDeleted    { get; set; }
        public DateTime? DeletedAtUtc { get; set; }
    }
}
