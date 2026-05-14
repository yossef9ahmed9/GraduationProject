// ═══════════════════════════════════════════════════════════════════
// PatientsController.cs  — updated
//
// Changes vs previous version:
//  1. GET /api/patients  →  commented out for the Doctor role explanation
//     (it still works for Admin / other roles — we did NOT remove it).
//  2. NEW GET /api/patients/doctor  →  returns only the patients that
//     have at least one FollowUp where DoctorId matches the calling
//     doctor's Doctor entity record (looked up by email from the JWT).
//
// The frontend sends:
//   Doctor role  →  GET /api/patients/doctor
//   Other roles  →  GET /api/patients   (unchanged)
// ═══════════════════════════════════════════════════════════════════

using GraduationProject.Contracts.Patients;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class PatientsController(IPatientService patientService, AppDbContext context) : ControllerBase
    {
        private readonly IPatientService _patientService = patientService;
        private readonly AppDbContext _context = context;

        // ── GET /api/patients ───────────────────────────────────────
        // Returns ALL patients.  Open to any authenticated role.
        // For the Doctor role the frontend now calls /patients/doctor
        // instead, so this endpoint is effectively unused by doctors —
        // but we keep it intact for Admin and other roles.
        [HttpGet]
        public async Task<IActionResult> GetPatients(CancellationToken cancellationToken)
        {
            return Ok(await _patientService.GetAllPatientsAsync(cancellationToken));
        }

        // ── NEW: GET /api/patients/doctor ───────────────────────────
        // Returns only the patients that belong to the calling doctor.
        // "Belong" means: there is at least one FollowUp whose DoctorId
        // matches this doctor's Doctor entity (matched by email claim).
        //
        // Route note: "doctor" must come BEFORE "{id}" to avoid being
        // swallowed by the parameterised route below.
        [HttpGet("doctor")]
        [Authorize(Roles = "Doctor")]
        public async Task<IActionResult> GetMyPatients(CancellationToken cancellationToken)
        {
            // The JWT "email" claim is set in JwtProvider using
            // JwtRegisteredClaimNames.Email — value is user.Email.
            var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                     ?? User.FindFirst("email")?.Value;

            if (string.IsNullOrEmpty(email))
                return Unauthorized();

            // Look up the Doctor entity that corresponds to this user.
            var doctor = await _context.Doctors
                .AsNoTracking()
                .FirstOrDefaultAsync(d => d.Email == email, cancellationToken);

            if (doctor == null)
                return NotFound(new { title = "Doctor record not found for the logged-in user." });

            // Collect the patient IDs linked to this doctor via FollowUps.
            var patientIds = await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.DoctorId == doctor.Id)
                .Select(f => f.PatientId)
                .Distinct()
                .ToListAsync(cancellationToken);

            // Fetch + project those patients using Mapster (same as GetAllPatientsAsync).
            var patients = await _context.Patients
                .AsNoTracking()
                .Where(p => patientIds.Contains(p.Id))
                .ProjectToType<PatientResponse>()
                .ToListAsync(cancellationToken);

            return Ok(patients);
        }

        // ── GET /api/patients/{id} ──────────────────────────────────
        [HttpGet("{id}")]
        public async Task<IActionResult> GetPatient(int id, CancellationToken cancellationToken)
        {
            var result = await _patientService.GetPatientAsync(id, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // ── POST /api/patients ──────────────────────────────────────
        [HttpPost]
        public async Task<IActionResult> CreatePatient(PatientRequest request, CancellationToken cancellationToken)
        {
            var result = await _patientService.AddPatientAsync(request, cancellationToken);

            return result.IsSuccess
                ? CreatedAtAction(nameof(GetPatient), new { id = result.Value.Id }, result.Value)
                : result.ToProblem();
        }

        // ── PUT /api/patients/{id} ──────────────────────────────────
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdatePatient(int id, PatientRequest request, CancellationToken cancellationToken)
        {
            var result = await _patientService.UpdatePatientAsync(id, request, cancellationToken);

            return result.IsSuccess
                ? NoContent()
                : result.ToProblem();
        }

        // ── DELETE /api/patients/{id} ───────────────────────────────
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePatient(int id, CancellationToken cancellationToken)
        {
            var result = await _patientService.DeletePatientAsync(id, cancellationToken);

            return result.IsSuccess
                ? NoContent()
                : result.ToProblem();
        }
    }
}
