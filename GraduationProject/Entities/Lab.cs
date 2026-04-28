namespace GraduationProject.Entities
{
    public class Lab
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Location { get; set; } = string.Empty;

        public string Phone { get; set; } = string.Empty;

        public ICollection<MedicalTest> MedicalTests { get; set; }
            = new List<MedicalTest>();
    }
}