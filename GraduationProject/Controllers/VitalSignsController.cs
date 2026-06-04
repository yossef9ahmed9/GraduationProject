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
        IAutoEmergencyService autoEmergency,
        AppDbContext context
        ) : ControllerBase
    {
        private readonly IVitalSignsService _service = service;
        private readonly IAutoEmergencyService _autoEmergency = autoEmergency;
        private readonly AppDbContext _context = context;

        [HttpGet]
        public async Task<IActionResult> Get([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetAllAsync(pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(
            int patientId,
            [FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetByPatientAsync(patientId, pageNumber, pageSize, cancellationToken));
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
        [Authorize(Roles = "Patient")]
        public async Task<IActionResult> Create(
            VitalSignsRequest request,
            CancellationToken cancellationToken)
        {
            var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                     ?? User.FindFirst("email")?.Value;

            if (!string.IsNullOrEmpty(email))
            {
                var patient = await _context.Patients
                    .AsNoTracking()
                    .FirstOrDefaultAsync(p => p.Email == email, cancellationToken);

                if (patient is null || patient.Id != request.PatientId)
                    return Forbid();
            }

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
