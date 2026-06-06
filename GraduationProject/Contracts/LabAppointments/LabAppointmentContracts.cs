namespace GraduationProject.Contracts.LabAppointments
{
    // ── Request ───────────────────────────────────────────────────────────────
    public record LabAppointmentRequest(
        int      PatientId,
        int      LabId,
        List<string> TestNames,        // e.g. ["CBC", "Glucose", "HbA1c"]
        DateTime AppointmentDate,
        string?  Notes
    );

    // ── Response ──────────────────────────────────────────────────────────────
    public record LabAppointmentResponse(
        int      Id,
        int      PatientId,
        string   PatientName,
        int      LabId,
        string   LabName,
        List<string> TestNames,
        DateTime AppointmentDate,
        string   Notes,
        string   Status,              // Pending / Confirmed / Completed / Cancelled
        DateTime CreatedAt
    );

    // ── Status update ─────────────────────────────────────────────────────────
    public record UpdateLabAppointmentStatusRequest(
        string Status
    );
}
