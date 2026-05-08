namespace GraduationProject.Entities
{
    // NEW FILE: tracks when an ambulance is dispatched to a patient emergency
    public class EmergencyDispatch
    {
        public int Id { get; set; }

        // when the emergency was triggered
        public DateTime DispatchedAt { get; set; }

        // when ambulance arrived (null if not yet arrived)
        public DateTime? ArrivedAt { get; set; }

        // when the case was resolved
        public DateTime? ResolvedAt { get; set; }

        // status of the dispatch
        // e.g. Pending, OnTheWay, Arrived, Resolved, Cancelled
        public string Status { get; set; } = "Pending";

        // patient location at time of emergency
        public double PatientLatitude { get; set; }
        public double PatientLongitude { get; set; }

        // notes from paramedics
        public string? Notes { get; set; }

        public int PatientId { get; set; }
        public Patient Patient { get; set; } = default!;

        public int AmbulanceId { get; set; }
        public Ambulance Ambulance { get; set; } = default!;
    }
}