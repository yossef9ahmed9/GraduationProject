namespace GraduationProject.Entities
{
    public class Doctor : ISoftDeletable
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Specialization { get; set; } = string.Empty;

        // Where the doctor works
        public string? HospitalName { get; set; }

        // Clinic info (optional)
        public string? ClinicName    { get; set; }
        public string? ClinicAddress { get; set; }
        public double? ClinicLatitude  { get; set; }
        public double? ClinicLongitude { get; set; }

        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }

        public string? FcmToken { get; set; }

        public ICollection<FollowUp> FollowUps { get; set; } = new List<FollowUp>();
    }
}