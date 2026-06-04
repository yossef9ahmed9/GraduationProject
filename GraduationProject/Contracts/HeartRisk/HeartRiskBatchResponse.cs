namespace GraduationProject.Contracts.HeartRisk
{
    public record HeartRiskBatchResponse(
        int Total,
        int CriticalCount,
        int WarningCount,
        int NormalCount,
        List<HeartRiskBatchItem> Results
    );

    public record HeartRiskBatchItem(
        int     Index,
        string? Tier,
        double? Score,
        bool?   Alert,
        string? Action,
        string? OverrideReason,
        string? Error
    );
}
