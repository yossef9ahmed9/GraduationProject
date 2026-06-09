namespace GraduationProject.Entities
{
    public class Relative : ISoftDeletable
    {
        public int    Id              { get; set; }
        public string Name            { get; set; } = string.Empty;
        public string Phone           { get; set; } = string.Empty;
        public string RelationType    { get; set; } = "Family";
        public string? Email          { get; set; }
        public bool   IsPrimaryContact { get; set; } = false;
        public string? FcmToken       { get; set; }

        // A relative can be linked to MULTIPLE patients via approved requests
        // PatientId (single) has been removed
        public ICollection<RelativePatientRequest> PatientRequests { get; set; }
            = new List<RelativePatientRequest>();

        public IEnumerable<int> ApprovedPatientIds =>
            PatientRequests.Where(r => r.Status == "Approved").Select(r => r.PatientId);

        public bool      IsDeleted    { get; set; }
        public DateTime? DeletedAtUtc { get; set; }
    }
}
