using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    // UPDATED: added [Authorize] — this was the only controller missing it
    // anyone could POST fake vital signs without a token before this fix
    [Authorize]
    public class VitalSignsController(
        IVitalSignsService service,
        IAutoEmergencyService autoEmergency   // NEW: injected so we can expose emergency info
        ) : ControllerBase
    {
        private readonly IVitalSignsService _service = service;
        // NEW: reference to the auto-emergency service for the manual-trigger endpoint
        private readonly IAutoEmergencyService _autoEmergency = autoEmergency;

        [HttpGet]
        public async Task<IActionResult> Get(CancellationToken cancellationToken)
        {
            return Ok(await _service.GetAllAsync(cancellationToken));
        }

        // NEW: get all vitals for a specific patient
        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(
            int patientId,
            CancellationToken cancellationToken)
        {
            return Ok(await _service.GetByPatientAsync(patientId, cancellationToken));
        }

        // NEW: get only the most recent reading for a patient
        [HttpGet("patient/{patientId}/latest")]
        public async Task<IActionResult> GetLatestByPatient(
            int patientId,
            CancellationToken cancellationToken)
        {
            var result = await _service.GetLatestByPatientAsync(patientId, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        [HttpPost]
        public async Task<IActionResult> Create(
            VitalSignsRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _service.AddAsync(request, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // NEW: POST /api/vitalsigns/{id}/check-emergency
        // Manually re-evaluates a saved vital-signs reading and triggers an emergency
        // dispatch if the values are critical and no dispatch exists yet.
        // Useful for admin tools or retry scenarios when the automatic trigger failed.
        [HttpPost("{id}/check-emergency")]
        public async Task<IActionResult> CheckEmergency(
            int id,
            CancellationToken cancellationToken)
        {
            var dispatch = await _autoEmergency.TryTriggerEmergencyAsync(id, cancellationToken);

            return dispatch is null
                ? Ok(new { message = "No emergency triggered. Values are within safe thresholds or an emergency is already active." })
                : Ok(new { message = "Emergency dispatch created.", dispatch });
        }
    }
}
