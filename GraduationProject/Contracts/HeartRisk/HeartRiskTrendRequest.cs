namespace GraduationProject.Contracts.HeartRisk
{
    /// <summary>
    /// A single historical reading sent as part of a trend analysis request.
    /// </summary>
    public record TrendReading(
        double Bpm,
        double Spo2,
        /// <summary>How many seconds ago this reading was taken. 0 = latest.</summary>
        double TimestampOffsetSec
    );

    /// <summary>
    /// Request body for POST /api/heartrisk/predict/trend.
    /// The backend populates this from recent VitalSigns rows automatically.
    /// </summary>
    public record HeartRiskTrendRequest(
        List<TrendReading> Readings,
        int    Age,
        int    Sex    = 1,
        double HrvMs  = 50.0
    );
}
