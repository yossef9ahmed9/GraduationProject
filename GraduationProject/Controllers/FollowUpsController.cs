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

        // Admin / all roles — returns everything
        [HttpGet]
        public async Task<IActionResult> Get(CancellationToken cancellationToken)
        {
            return Ok(await _service.GetAllAsync(cancellationToken));
        }

        // GET /api/followups/doctor
        // Reads the signed-in user's email, finds their Doctor record, returns only their follow-ups
        [HttpGet("doctor")]
        public async Task<IActionResult> GetForDoctor(CancellationToken cancellationToken)
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

            return Ok(await _service.GetByDoctorAsync(doctor.Id, cancellationToken));
        }

        // GET /api/followups/patient/{id}
        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetForPatient(
            int patientId, CancellationToken cancellationToken)
        {
            return Ok(await _service.GetByPatientAsync(patientId, cancellationToken));
        }

        [HttpPost]
        public async Task<IActionResult> Create(
            FollowUpRequest request, CancellationToken cancellationToken)
        {
            var result = await _service.AddAsync(request, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }
    }
}