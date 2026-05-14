namespace GraduationProject.Entities
{
    public class FollowUp : ISoftDeletable
    {
        public int Id { get; set; }
        public string Diagnosis { get; set; } = string.Empty;
        public string TreatmentPlan { get; set; } = string.Empty;
        public string Notes { get; set; } = string.Empty;
        public DateTime LastUpdate { get; set; }

        // NEW: when is the patient's next visit
        public DateTime? NextVisitDate { get; set; }

        // NEW: track the severity level of the case
        // e.g. Low, Medium, High, Critical
        public string Severity { get; set; } = "Low";

        public int PatientId { get; set; }
        public Patient Patient { get; set; } = default!;

        public int DoctorId { get; set; }
        public Doctor Doctor { get; set; } = default!;

        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }
    }
}