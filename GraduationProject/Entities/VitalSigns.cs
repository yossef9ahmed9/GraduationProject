namespace GraduationProject.Entities
{
    public class VitalSigns
    {
        public int Id { get; set; }

        public int HeartRate { get; set; }

        public int? BloodPressureSystolic { get; set; }
        public int? BloodPressureDiastolic { get; set; }
        public double? OxygenSaturation { get; set; }
        public double? Temperature { get; set; }
        public int? RespiratoryRate { get; set; }
        public double? BloodGlucose { get; set; }

        public bool EmergencyStatus { get; set; }
        public DateTime TimeStamp { get; set; }

        // existing: sensor relationship
        public int SensorId { get; set; }
        public Sensor Sensor { get; set; } = default!;

        // NEW: direct link to patient so we dont have to go through sensor every time
        public int PatientId { get; set; }
        public Patient Patient { get; set; } = default!;
    }
}