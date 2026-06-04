// ============================================================
// File: GraduationProject/Controllers/HeartRiskController.cs
// ============================================================
//
// Endpoints:
//   POST /api/heartrisk/predict         — single reading
//   POST /api/heartrisk/predict/window  — 30-s averaged window (recommended)
//   POST /api/heartrisk/predict/batch   — flush buffered readings
//   POST /api/heartrisk/predict/vitals/{vitalSignsId}
//                                       — run AI on an already-saved VitalSigns row
//   GET  /api/heartrisk/health          — check if Python service is reachable
// ============================================================

using GraduationProject.Contracts.HeartRisk;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class HeartRiskController(
        IHeartRiskService heartRiskService,
        AppDbContext context) : ControllerBase
    {
        private readonly IHeartRiskService _heartRiskService = heartRiskService;
        private readonly AppDbContext      _context          = context;

        // ── POST /api/heartrisk/predict ───────────────────────────────────────
        /// <summary>
        /// Send a single MAX30102 reading and get an instant risk assessment.
        /// If the model returns CRITICAL, the response includes alert: true —
        /// your frontend/device should react accordingly (e.g. confirm dispatch).
        /// </summary>
        [HttpPost("predict")]
        public async Task<IActionResult> Predict(
            HeartRiskRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _heartRiskService.PredictAsync(request, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // ── POST /api/heartrisk/predict/window ────────────────────────────────
        /// <summary>
        /// Recommended for real MAX30102 hardware.
        /// Collect 30 seconds of readings on the device, compute averages and
        /// minimums, then send the summary here. Uses worst-case SpO2 (minimum)
        /// so the assessment is always on the safe side.
        /// </summary>
        [HttpPost("predict/window")]
        public async Task<IActionResult> PredictWindow(
            HeartRiskWindowRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _heartRiskService.PredictWindowAsync(request, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // ── POST /api/heartrisk/predict/batch ─────────────────────────────────
        /// <summary>
        /// Flush up to 200 buffered readings from a device queue in one HTTP call.
        /// Returns per-reading results plus aggregate counts (critical / warning / normal).
        /// </summary>
        [HttpPost("predict/batch")]
        public async Task<IActionResult> PredictBatch(
            HeartRiskBatchRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _heartRiskService.PredictBatchAsync(request, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // ── POST /api/heartrisk/predict/vitals/{vitalSignsId} ─────────────────
        /// <summary>
        /// Run the AI model on a VitalSigns row that is already saved in the database.
        /// Useful for re-analysing historical readings or triggering the AI after the
        /// fact without re-posting raw sensor data.
        ///
        /// The PatientId on the VitalSigns row is used to pull age and sex from the
        /// Patient record automatically — no extra inputs required.
        /// </summary>
        [HttpPost("predict/vitals/{vitalSignsId:int}")]
        public async Task<IActionResult> PredictFromVitalSigns(
            int vitalSignsId,
            CancellationToken cancellationToken)
        {
            // Load the vital signs row with its patient
            var vital = await _context.VitalSigns
                .AsNoTracking()
                .Include(v => v.Patient)
                .FirstOrDefaultAsync(v => v.Id == vitalSignsId, cancellationToken);

            if (vital is null)
                return NotFound(new { message = $"VitalSigns with ID {vitalSignsId} not found." });

            // HRV is not stored on the VitalSigns entity — use a safe default of 50 ms
            // if the device did not provide it. This still gives a valid risk estimate.
            var request = new HeartRiskRequest(
                Bpm    : vital.HeartRate,
                Spo2   : vital.OxygenSaturation ?? 98.0,
                HrvMs  : 50.0,                            // default — MAX30102 HRV not stored yet
                Age    : CalculateAge(vital.Patient.BirthDate),
                Sex    : vital.Patient.Gender.ToLower() == "male" ? 1 : 0
            );

            var result = await _heartRiskService.PredictAsync(request, cancellationToken);

            if (!result.IsSuccess)
                return result.ToProblem();

            // Return the AI result plus the source vital signs ID for traceability
            return Ok(new
            {
                vitalSignsId,
                patientId   = vital.PatientId,
                patientName = vital.Patient.Name,
                aiAssessment = result.Value,
            });
        }

        // ── GET /api/heartrisk/health ─────────────────────────────────────────
        /// <summary>
        /// Checks whether the Python AI service is reachable.
        /// Returns 200 OK with { healthy: true } or 503 with { healthy: false }.
        /// </summary>
        [HttpGet("health")]
        public async Task<IActionResult> Health(CancellationToken cancellationToken)
        {
            var healthy = await _heartRiskService.IsHealthyAsync(cancellationToken);

            return healthy
                ? Ok(new  { healthy = true,  message = "AI model service is running." })
                : StatusCode(503, new { healthy = false, message = "AI model service is unavailable." });
        }

        // ─────────────────────────────────────────────────────────────────────
        // Private helpers
        // ─────────────────────────────────────────────────────────────────────
        private static int CalculateAge(DateOnly birthDate)
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            var age   = today.Year - birthDate.Year;
            if (birthDate > today.AddYears(-age)) age--;
            return Math.Max(1, age);
        }
    }
}
