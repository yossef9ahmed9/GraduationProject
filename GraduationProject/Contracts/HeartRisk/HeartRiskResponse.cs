namespace GraduationProject.Contracts.HeartRisk
{
    /// <summary>
    /// Response returned by the Python AI model and forwarded to the client.
    /// </summary>
    public record HeartRiskResponse(
        /// <summary>NORMAL / WARNING / CRITICAL</summary>
        string Tier,

        /// <summary>Critical probability 0–100</summary>
        double Score,

        /// <summary>Model confidence 0–100</summary>
        double Confidence,

        /// <summary>Short recommended action for the patient / carer</summary>
        string Action,

        /// <summary>Detailed patient-facing advice</summary>
        string Message,

        /// <summary>True → trigger ambulance dispatch from the .NET side</summary>
        bool Alert,

        /// <summary>Non-null when a hard threshold fired and overrode the model</summary>
        string? OverrideReason,

        /// <summary>Probability % for each tier</summary>
        HeartRiskProbabilities Probabilities
    );

    public record HeartRiskProbabilities(
        double Normal,
        double Warning,
        double Critical
    );
}
