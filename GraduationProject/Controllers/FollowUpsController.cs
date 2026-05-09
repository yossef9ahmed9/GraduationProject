using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class FollowUpsController(IFollowUpService service) : ControllerBase
    {
        private readonly IFollowUpService _service = service;

        [HttpGet]
        public async Task<IActionResult> Get(CancellationToken cancellationToken)
        {
            return Ok(await _service.GetAllAsync(cancellationToken));
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> Get(int id, CancellationToken cancellationToken)
        {
            var result = await _service.GetAsync(id, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(int patientId, CancellationToken cancellationToken)
        {
            return Ok(await _service.GetByPatientAsync(patientId, cancellationToken));
        }

        [HttpGet("doctor/{doctorId}")]
        public async Task<IActionResult> GetByDoctor(int doctorId, CancellationToken cancellationToken)
        {
            return Ok(await _service.GetByDoctorAsync(doctorId, cancellationToken));
        }

        [HttpPost]
        public async Task<IActionResult> Create(FollowUpRequest request, CancellationToken cancellationToken)
        {
            var result = await _service.AddAsync(request, cancellationToken);

            return result.IsSuccess
                ? CreatedAtAction(nameof(Get), new { id = result.Value.Id }, result.Value)
                : result.ToProblem();
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, FollowUpRequest request, CancellationToken cancellationToken)
        {
            var result = await _service.UpdateAsync(id, request, cancellationToken);

            return result.IsSuccess
                ? NoContent()
                : result.ToProblem();
        }

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
