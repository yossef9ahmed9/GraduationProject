namespace GraduationProject.Contracts.Sensors
{
    // FIXED: IsActive and LastPing were already in this record — the entity fields
    // and the response were actually in sync. Keeping file for completeness.
    public record SensorResponse(
        int Id,
        string Type,
        string Description,
        int PatientId,
        bool IsActive,
        DateTime? LastPing
    );
}
