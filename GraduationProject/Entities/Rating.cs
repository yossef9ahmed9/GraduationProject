namespace GraduationProject.Entities
{
    /// <summary>
    /// Stores one rating (1–5 stars) per patient per target (doctor or lab).
    /// A patient can rate the same doctor/lab multiple times — the latest value wins.
    /// </summary>
    public class Rating
    {
        public int Id { get; set; }

        // Who submitted the rating
        public int PatientId { get; set; }
        public Patient Patient { get; set; } = null!;

        // Target — exactly one of these is set
        public int? DoctorId { get; set; }
        public Doctor? Doctor { get; set; }

        public int? LabId { get; set; }
        public Lab? Lab { get; set; }

        // 1 – 5 (whole or half stars)
        public double Stars { get; set; }

        public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
    }
}
