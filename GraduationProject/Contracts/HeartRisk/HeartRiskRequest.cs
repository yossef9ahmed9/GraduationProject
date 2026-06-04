namespace GraduationProject.Contracts.HeartRisk
{
    /// <summary>
    /// Sent to the Python AI model (POST /predict).
    /// All values come directly from the MAX30102 sensor + patient profile.
    /// </summary>
    public record HeartRiskRequest(
        /// <summary>Heart rate in beats per minute (20–300)</summary>
        double Bpm,

        /// <summary>Blood oxygen saturation % (50–100)</summary>
        double Spo2,

        /// <summary>Heart rate variability in milliseconds (1–200)</summary>
        double HrvMs,

        /// <summary>Patient age in years (1–120)</summary>
        int Age,

        /// <summary>0 = female, 1 = male (default 1)</summary>
        int Sex = 1
    );
}
