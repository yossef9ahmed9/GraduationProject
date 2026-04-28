namespace GraduationProject.Entities
{
    public class FollowUp
    {
        public int Id { get; set; }

        public string Diagnosis { get; set; } = string.Empty;

        public string TreatmentPlan { get; set; } = string.Empty;

        public string Notes { get; set; } = string.Empty;

        public DateTime LastUpdate { get; set; }

        public int PatientId { get; set; }

        public Patient Patient { get; set; } = default!;

        public int DoctorId { get; set; }

        public Doctor Doctor { get; set; } = default!;
    }
}