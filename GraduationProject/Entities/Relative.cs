namespace GraduationProject.Entities
{
    public class Relative
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string RelationType { get; set; } = string.Empty;

        // NEW: to send emergency email notifications to relative
        public string? Email { get; set; }

        // NEW: primary contact gets notified first in emergencies
        public bool IsPrimaryContact { get; set; } = false;

        public int PatientId { get; set; }
        public Patient Patient { get; set; } = default!;
    }
}