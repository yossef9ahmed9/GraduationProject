namespace GraduationProject.Entities
{
    public class Ambulance : ISoftDeletable
    {
        public int      Id                 { get; set; }
        public string   Email              { get; set; } = string.Empty;
        public string   Phone              { get; set; } = string.Empty;
        public string   AvailabilityStatus { get; set; } = "NotAvailable";

        // Real-time GPS — updated by the ambulance app continuously
        public double?   Latitude            { get; set; }
        public double?   Longitude           { get; set; }
        public DateTime? LastLocationUpdate  { get; set; }

        // Driver info — DriverName is the primary display name
        public string   DriverName    { get; set; } = string.Empty;
        public string   DriverPhone   { get; set; } = string.Empty;
        public string   LicensePlate  { get; set; } = string.Empty;

        // Optional area/zone label (e.g. "Nasr City", "Shubra")
        public string?  ServiceArea   { get; set; }

        // FCM push token — updated by the app after every login
        public string?  FcmToken      { get; set; }

        public bool      IsDeleted     { get; set; }
        public DateTime? DeletedAtUtc  { get; set; }

        public ICollection<EmergencyDispatch> EmergencyDispatches { get; set; }
            = new List<EmergencyDispatch>();
    }
}
