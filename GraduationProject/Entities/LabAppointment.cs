namespace GraduationProject.Entities
{
    // ════════════════════════════════════════════════════════════════
    // LabAppointment — patient books a test at a specific lab
    // Separate from MedicalTest (which stores the result/OCR)
    // ════════════════════════════════════════════════════════════════
    public class LabAppointment : ISoftDeletable
    {
        public int      Id          { get; set; }
        public int      PatientId   { get; set; }
        public int      LabId       { get; set; }

        // Comma-separated test names e.g. "CBC,Glucose,HbA1c"
        public string   TestNames   { get; set; } = string.Empty;

        public DateTime AppointmentDate { get; set; }
        public string   Notes       { get; set; } = string.Empty;

        // Pending / Confirmed / Completed / Cancelled
        public string   Status      { get; set; } = "Pending";

        public DateTime CreatedAt   { get; set; } = DateTime.UtcNow;

        // Navigation
        public Patient  Patient     { get; set; } = default!;
        public Lab      Lab         { get; set; } = default!;

        public bool     IsDeleted    { get; set; }
        public DateTime? DeletedAtUtc { get; set; }
    }
}
