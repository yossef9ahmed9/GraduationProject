namespace GraduationProject.Entities
{
    public class Relative : ISoftDeletable
    {
        public int    Id               { get; set; }
        public string Name             { get; set; } = string.Empty;
        public string Phone            { get; set; } = string.Empty;
        public string RelationType     { get; set; } = string.Empty;
        public string? Email           { get; set; }
        public bool   IsPrimaryContact { get; set; } = false;
        public string? FcmToken        { get; set; }

        // Null until a RelativePatientRequest is Approved
        public int?    PatientId { get; set; }
        public Patient? Patient  { get; set; }

        public ICollection<RelativePatientRequest> PatientRequests { get; set; }
            = new List<RelativePatientRequest>();

        public bool      IsDeleted    { get; set; }
        public DateTime? DeletedAtUtc { get; set; }
    }
}
