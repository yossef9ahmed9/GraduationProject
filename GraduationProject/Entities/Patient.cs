namespace GraduationProject.Entities
{
    public class Patient : ISoftDeletable
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Gender { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public DateOnly BirthDate { get; set; }
        public string MedicalRecord { get; set; } = string.Empty;
        public string BloodType { get; set; } = string.Empty;
        public string? ChronicDiseases { get; set; }
        public string? Allergies { get; set; }
        public bool IsInEmergency { get; set; } = false;
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public DateTime? LastLocationUpdate { get; set; }

        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }

        public ICollection<Relative> Relatives { get; set; } = new List<Relative>();
        public ICollection<Sensor> Sensors { get; set; } = new List<Sensor>();
        public ICollection<MedicalTest> MedicalTests { get; set; } = new List<MedicalTest>();
        public ICollection<FollowUp> FollowUps { get; set; } = new List<FollowUp>();
        public ICollection<EmergencyDispatch> EmergencyDispatches { get; set; } = new List<EmergencyDispatch>();

        // NEW: direct collection of all vitals for this patient across all sensors
        public ICollection<VitalSigns> VitalSigns { get; set; } = new List<VitalSigns>();
    }
}