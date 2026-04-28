namespace GraduationProject.Entities
{
    public class Sensor
    {
        public int Id { get; set; }

        public string Type { get; set; } = string.Empty;

        public string Description { get; set; } = string.Empty;

        public int PatientId { get; set; }

        public Patient Patient { get; set; } = default!;

        public ICollection<VitalSigns> VitalSigns { get; set; }
            = new List<VitalSigns>();
    }
}
