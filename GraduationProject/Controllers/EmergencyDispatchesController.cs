using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Controllers
{
    // NEW FILE: controller that exposes the emergency dispatch feature via the API
    // previously the EmergencyDispatch entity existed with full migrations
    // but there was no controller or service — so the feature was completely unreachable
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class EmergencyDispatchesController(IEmergencyDispatchService service) : ControllerBase
    {
        private readonly IEmergencyDispatchService _service = service;

        // GET /api/emergencydispatches
        // returns all dispatches — admin / overview use case
        [HttpGet]
        public async Task<IActionResult> Get(CancellationToken cancellationToken)
        {
            return Ok(await _service.GetAllAsync(cancellationToken));
        }

        // GET /api/emergencydispatches/patient/{patientId}
        // returns dispatch history for one patient — newest first
        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(int patientId, CancellationToken cancellationToken)
        {
            return Ok(await _service.GetByPatientAsync(patientId, cancellationToken));
        }

        // GET /api/emergencydispatches/ambulance/{ambulanceId}
        // returns dispatch history for one ambulance — newest first
        [HttpGet("ambulance/{ambulanceId}")]
        public async Task<IActionResult> GetByAmbulance(int ambulanceId, CancellationToken cancellationToken)
        {
            return Ok(await _service.GetByAmbulanceAsync(ambulanceId, cancellationToken));
        }

        // POST /api/emergencydispatches
        // triggers a new emergency dispatch — sets ambulance status to Busy
        [HttpPost]
        public async Task<IActionResult> Create(
            EmergencyDispatchRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _service.AddAsync(request, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // PATCH /api/emergencydispatches/{id}/status
        // updates the dispatch lifecycle: Pending → OnTheWay → Arrived → Resolved / Cancelled
        // auto-stamps ArrivedAt and ResolvedAt when those statuses are set
        // frees the ambulance back to Available when Resolved or Cancelled
        [HttpPatch("{id}/status")]
        public async Task<IActionResult> UpdateStatus(
            int id,
            [FromBody] string status,
            CancellationToken cancellationToken)
        {
            var result = await _service.UpdateStatusAsync(id, status, cancellationToken);

            return result.IsSuccess
                ? NoContent()
                : result.ToProblem();
        }
    }
}
