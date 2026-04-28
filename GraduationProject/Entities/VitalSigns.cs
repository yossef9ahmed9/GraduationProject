namespace GraduationProject.Entities
{
    public class VitalSigns
    {
        public int Id { get; set; }

        public int HeartRate { get; set; }

        public bool EmergencyStatus { get; set; }

        public DateTime TimeStamp { get; set; }

        public int SensorId { get; set; }

        public Sensor Sensor { get; set; } = default!;
    }
}
