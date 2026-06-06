namespace GraduationProject.Entities
{
    public class VitalSigns : ISoftDeletable
    {
        public int Id { get; set; }
        public int HeartRate { get; set; }
        public double OxygenSaturation { get; set; }
        public bool EmergencyStatus { get; set; }
        public DateTime TimeStamp { get; set; }

        public int SensorId { get; set; }
        public Sensor Sensor { get; set; } = default!;

        public int PatientId { get; set; }
        public Patient Patient { get; set; } = default!;

        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }
    }
}