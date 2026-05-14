namespace GraduationProject.Entities
{
    public class Ambulance : ISoftDeletable
    {
        public int Id { get; set; }
        public string StationName { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string AvailabilityStatus { get; set; } = string.Empty; // Available, Busy, OutOfService

        // NEW: real-time location so you can find nearest ambulance
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public DateTime? LastLocationUpdate { get; set; }

        // NEW: ambulance details
        public string LicensePlate { get; set; } = string.Empty;
        public string DriverName { get; set; } = string.Empty;
        public string DriverPhone { get; set; } = string.Empty;

        public bool IsDeleted { get; set; }
        public DateTime? DeletedAtUtc { get; set; }

        // NEW: track which dispatches this ambulance handled
        public ICollection<EmergencyDispatch> EmergencyDispatches { get; set; }
            = new List<EmergencyDispatch>();
    }
}