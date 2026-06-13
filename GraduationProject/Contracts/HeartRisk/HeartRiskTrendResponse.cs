namespace GraduationProject.Contracts.HeartRisk
{
    /// <summary>
    /// Trend forecast returned by POST /api/heartrisk/predict/trend.
    /// </summary>
    public record HeartRiskTrendResponse(
        string  CurrentTier,
        string  TrendDirection,
        double  BpmSlope,
        double  Spo2Slope,
        string  ForecastTier5Min,
        string  ForecastTier10Min,
        bool    Alert,
        string  Message,
        double  Confidence,
        /// <summary>Minutes until a danger threshold is crossed. Null if not approaching any threshold.</summary>
        double? TimeToDangerMin
    );
}
