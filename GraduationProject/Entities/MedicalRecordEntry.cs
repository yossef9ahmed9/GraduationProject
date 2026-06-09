namespace GraduationProject.Entities
{
    public class MedicalRecordEntry : ISoftDeletable
    {
        public int      Id          { get; set; }
        public int      PatientId   { get; set; }

        // Who wrote this entry
        public string  AuthorEmail { get; set; } = string.Empty;
        public string  AuthorName  { get; set; } = string.Empty;
        public string  AuthorRole  { get; set; } = string.Empty; // Doctor | Patient | Admin

        // What changed — any field may be null if it was not updated in this entry
        public string? MedicalRecord   { get; set; }
        public string? ChronicDiseases { get; set; }
        public string? Allergies       { get; set; }
        public string? BloodType       { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public Patient  Patient   { get; set; } = default!;

        public bool      IsDeleted    { get; set; }
        public DateTime? DeletedAtUtc { get; set; }
    }
}
