namespace GraduationProject.Contracts.HeartRisk
{
    /// <summary>
    /// 30-second averaged window — recommended for production devices.
    /// The device collects 30 s of readings, computes averages/minimums,
    /// then sends this payload. Uses worst-case (minimum) SpO2.
    /// </summary>
    public record HeartRiskWindowRequest(
        double BpmAvg,
        double BpmMin,
        double BpmMax,
        double Spo2Avg,
        double Spo2Min,
        double HrvMs,
        int    Age,
        int    Sex = 1
    );
}
