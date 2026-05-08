namespace GraduationProject.Entities
{
    public class Doctor
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Specialization { get; set; } = string.Empty;

        // NEW: where the doctor works
        public string? HospitalName { get; set; }

        // NEW: doctor availability for appointments
        public bool IsAvailable { get; set; } = true;

        public ICollection<FollowUp> FollowUps { get; set; } = new List<FollowUp>();
    }
}