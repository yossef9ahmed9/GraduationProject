// ============================================================
// File: GraduationProject/Services/IHeartRiskService.cs
// ============================================================
using GraduationProject.Contracts.HeartRisk;

namespace GraduationProject.Services
{
    /// <summary>
    /// Thin wrapper around the MAX30102 Python AI micro-service.
    /// All methods call the FastAPI server and return typed results.
    /// </summary>
    public interface IHeartRiskService
    {
        /// <summary>
        /// Single reading → risk assessment.
        /// Call this every time you POST a VitalSigns reading.
        /// </summary>
        Task<Result<HeartRiskResponse>> PredictAsync(
            HeartRiskRequest request,
            CancellationToken cancellationToken = default);

        /// <summary>
        /// 30-second averaged window prediction (recommended for real devices).
        /// The device averages 30 s of data and sends the summary here.
        /// </summary>
        Task<Result<HeartRiskResponse>> PredictWindowAsync(
            HeartRiskWindowRequest request,
            CancellationToken cancellationToken = default);

        /// <summary>
        /// Batch prediction — flush up to 200 buffered readings at once.
        /// </summary>
        Task<Result<HeartRiskBatchResponse>> PredictBatchAsync(
            HeartRiskBatchRequest request,
            CancellationToken cancellationToken = default);

        /// <summary>True when the Python service is reachable and healthy.</summary>
        Task<bool> IsHealthyAsync(CancellationToken cancellationToken = default);

        /// <summary>
        /// Trend analysis — send the last N VitalSigns readings for a patient
        /// and get a near-future risk forecast (5 min / 10 min).
        /// The backend loads the readings from DB automatically.
        /// </summary>
        Task<Result<HeartRiskTrendResponse>> PredictTrendAsync(
            int patientId,
            CancellationToken cancellationToken = default);
    }
}
