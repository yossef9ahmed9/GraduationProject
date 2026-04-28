namespace GraduationProject.Entities
{
    public class MedicalTest
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Result { get; set; } = string.Empty;

        public DateTime Date { get; set; }

        public int PatientId { get; set; }

        public Patient Patient { get; set; } = default!;

        public int LabId { get; set; }

        public Lab Lab { get; set; } = default!;
    }
}
