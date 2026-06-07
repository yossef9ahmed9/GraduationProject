namespace GraduationProject.Contracts.PatientProgress
{
    public record PatientProgressPointResponse(
        DateTime Timestamp,
        int      HeartRate,
        double   OxygenSaturation,
        bool     EmergencyStatus
    );

    public record PatientProgressSummaryResponse(
        int    TotalReadings,
        double AverageHeartRate,
        double AverageOxygenSaturation,
        int    MinHeartRate,
        int    MaxHeartRate,
        double MinOxygenSaturation,
        double MaxOxygenSaturation,
        int    EmergencyReadings
    );

    public record MedicalTestPoint(
        DateTime Date,
        string   Name,
        string   Result,
        int      LabId,
        string   LabName
    );

    public record PatientProgressResponse(
        int                                      PatientId,
        string                                   PatientName,
        DateTime?                                From,
        DateTime?                                To,
        PatientProgressSummaryResponse           Summary,
        IReadOnlyList<PatientProgressPointResponse> Points,
        IReadOnlyList<MedicalTestPoint>          Tests
    );
}
