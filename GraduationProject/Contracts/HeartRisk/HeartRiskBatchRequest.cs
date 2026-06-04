namespace GraduationProject.Contracts.HeartRisk
{
    /// <summary>Send up to 200 readings at once (e.g. flush a device buffer).</summary>
    public record HeartRiskBatchRequest(
        List<HeartRiskRequest> Readings
    );
}
