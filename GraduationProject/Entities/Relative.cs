namespace GraduationProject.Entities
{
    public class Relative
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Phone { get; set; } = string.Empty;

        public string RelationType { get; set; } = string.Empty;

        public int PatientId { get; set; }

        public Patient Patient { get; set; } = default!;
    }
}