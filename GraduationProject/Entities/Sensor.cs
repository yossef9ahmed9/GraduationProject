namespace GraduationProject.Entities
{
    public class Sensor : ISoftDeletable
    {
        public int Id { get; set; }
        public string Type { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        // NEW: know if sensor is working or not
        public bool IsActive { get; set; } = true;

        // NEW: when the sensor last sent data (detect offline sensors)
        public DateTime? LastPing { get; set; }

        public int PatientId { get; set; }
        public Patient Patient { get; set; } = default!;

        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }

        public ICollection<VitalSigns> VitalSigns { get; set; } = new List<VitalSigns>();
    }
}