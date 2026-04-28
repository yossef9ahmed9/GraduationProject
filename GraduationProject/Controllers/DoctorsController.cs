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
        public async Task<IActionResult> Get()
        {
            var data = await _service.GetAllAsync();
            return Ok(data.Adapt<IEnumerable<DoctorResponse>>());
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> Get(int id)
        {
            var doctor = await _service.GetAsync(id);
            if (doctor == null) return NotFound();
            return Ok(doctor.Adapt<DoctorResponse>());
        }

        [HttpPost]
        public async Task<IActionResult> Create(DoctorRequest request)
        {
            var doctor = await _service.AddAsync(request.Adapt<Doctor>());
            return Ok(doctor);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, DoctorRequest request)
        {
            var updated = await _service.UpdateAsync(id, request.Adapt<Doctor>());
            return updated ? NoContent() : NotFound();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var deleted = await _service.DeleteAsync(id);
            return deleted ? NoContent() : NotFound();
        }
    }
}