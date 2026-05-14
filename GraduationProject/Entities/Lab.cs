namespace GraduationProject.Entities
{
    public class Lab : ISoftDeletable
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Location { get; set; } = string.Empty;

        public string Phone { get; set; } = string.Empty;

        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }

        public ICollection<MedicalTest> MedicalTests { get; set; }
            = new List<MedicalTest>();
    }
}