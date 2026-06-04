using GraduationProject.Contracts.Doctors;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class DoctorsController(IDoctorService service) : ControllerBase
    {
        private readonly IDoctorService _service = service;

        [HttpGet]
        public async Task<IActionResult> Get([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetAllAsync(pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> Get(int id, CancellationToken cancellationToken)
        {
            var result = await _service.GetAsync(id, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        [HttpPost]
        public async Task<IActionResult> Create(DoctorRequest request, CancellationToken cancellationToken)
        {
            var result = await _service.AddAsync(request, cancellationToken);

            return result.IsSuccess
                ? CreatedAtAction(nameof(Get), new { id = result.Value.Id }, result.Value)
                : result.ToProblem();
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, DoctorRequest request, CancellationToken cancellationToken)
        {
            var result = await _service.UpdateAsync(id, request, cancellationToken);

            return result.IsSuccess
                ? NoContent()
                : result.ToProblem();
        }

        [HttpPut("{id}/availability")]
        public async Task<IActionResult> UpdateAvailability(int id, [FromBody] UpdateDoctorAvailabilityRequest request, CancellationToken cancellationToken)
        {
            var result = await _service.UpdateAvailabilityAsync(id, request.IsAvailable, cancellationToken);

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