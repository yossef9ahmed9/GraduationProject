using GraduationProject.Contracts.Sensors;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SensorsController(ISensorService service) : ControllerBase
    {
        private readonly ISensorService _service = service;

        [HttpGet]
        public async Task<IActionResult> Get()
            => Ok((await _service.GetAllAsync()).Adapt<IEnumerable<SensorResponse>>());

        [HttpPost]
        public async Task<IActionResult> Create(SensorRequest request)
        {
            var sensor = await _service.AddAsync(request.Adapt<Sensor>());
            return Ok(sensor);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _service.DeleteAsync(id);
            return deleted ? NoContent() : NotFound();
        }
    }
}