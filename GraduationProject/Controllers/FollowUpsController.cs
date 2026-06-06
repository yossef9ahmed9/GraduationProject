using System.Security.Claims;
using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class FollowUpsController(
        IFollowUpService service,
        AppDbContext context) : ControllerBase
    {
        private readonly IFollowUpService _service = service;
        private readonly AppDbContext _context = context;

        [HttpGet]
        public async Task<IActionResult> Get([FromQuery] FollowUpFilter filter, CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetAllAsync(filter, cancellationToken));
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> Get(int id, CancellationToken cancellationToken)
        {
            var result = await _service.GetAsync(id, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        [HttpGet("doctor")]
        public async Task<IActionResult> GetForDoctor([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            var email = User.FindFirstValue(ClaimTypes.Email)
                        ?? User.FindFirstValue(JwtRegisteredClaimNames.Email);

            if (string.IsNullOrEmpty(email))
                return Unauthorized();

            var doctor = await _context.Doctors
                .AsNoTracking()
                .FirstOrDefaultAsync(d => d.Email == email, cancellationToken);

            if (doctor is null)
                return NotFound(new { message = "No doctor record linked to this account." });

            return Ok(await _service.GetByDoctorAsync(doctor.Id, pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("doctor/{doctorId}")]
        public async Task<IActionResult> GetByDoctor(int doctorId, [FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetByDoctorAsync(doctorId, pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("patient")]
        public async Task<IActionResult> GetForPatient([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 50, CancellationToken cancellationToken = default)
        {
            var email = User.FindFirstValue(ClaimTypes.Email)
                        ?? User.FindFirstValue(JwtRegisteredClaimNames.Email);

            if (string.IsNullOrEmpty(email))
                return Unauthorized();

            var patient = await _context.Patients
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Email == email, cancellationToken);

            if (patient is null)
                return NotFound(new { message = "No patient record linked to this account." });

            return Ok(await _service.GetByPatientAsync(patient.Id, pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(int patientId, [FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetByPatientAsync(patientId, pageNumber, pageSize, cancellationToken));
        }
        [HttpPost]
        public async Task<IActionResult> Create(
            FollowUpRequest request, CancellationToken cancellationToken)
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
