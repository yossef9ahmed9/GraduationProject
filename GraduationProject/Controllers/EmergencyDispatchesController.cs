using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class EmergencyDispatchesController(IEmergencyDispatchService service) : ControllerBase
    {
        private readonly IEmergencyDispatchService _service = service;

        // GET /api/emergencydispatches
        [HttpGet]
        public async Task<IActionResult> Get(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetAllAsync(pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(
            int patientId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetByPatientAsync(patientId, pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("ambulance/{ambulanceId}")]
        public async Task<IActionResult> GetByAmbulance(
            int ambulanceId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetByAmbulanceAsync(ambulanceId, pageNumber, pageSize, cancellationToken));
        }

        // POST /api/emergencydispatches
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
        // Pending → OnTheWay → Arrived → Resolved / Cancelled
        // Auto-stamps ArrivedAt / ResolvedAt; frees ambulance when done
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

        // DELETE /api/emergencydispatches/{id}
        // Only Resolved or Cancelled dispatches may be deleted
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
        {
            var result = await _service.DeleteAsync(id, cancellationToken);

            return result.IsSuccess
                ? NoContent()
                : result.ToProblem();
        }
    }
}
