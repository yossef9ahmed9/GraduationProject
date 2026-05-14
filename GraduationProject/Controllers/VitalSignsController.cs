using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    // UPDATED: added [Authorize] — this was the only controller missing it
    // anyone could POST fake vital signs without a token before this fix
    [Authorize]
    public class VitalSignsController(IVitalSignsService service) : ControllerBase
    {
        private readonly IVitalSignsService _service = service;

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
    }
}
