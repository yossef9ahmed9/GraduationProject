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
        public async Task<IActionResult> GetPatients([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return Ok(await _patientService.GetAllPatientsAsync(pageNumber, pageSize, cancellationToken));
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
        public async Task<IActionResult> GetMyPatients([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                     ?? User.FindFirst("email")?.Value;

            if (string.IsNullOrEmpty(email))
                return Unauthorized();

            var doctor = await _context.Doctors
                .AsNoTracking()
                .FirstOrDefaultAsync(d => d.Email == email, cancellationToken);

            if (doctor == null)
                return NotFound(new { title = "Doctor record not found for the logged-in user." });

            var patientIds = await _context.FollowUps
                .AsNoTracking()
                .Where(f => f.DoctorId == doctor.Id)
                .Select(f => f.PatientId)
                .Distinct()
                .ToListAsync(cancellationToken);

            var patientList = await _context.Patients
                .AsNoTracking()
                .Where(p => patientIds.Contains(p.Id))
                .OrderBy(p => p.Id)
                .ToListAsync(cancellationToken);

            var picMap = await _context.Users
                .AsNoTracking()
                .Where(u => patientList.Select(p => p.Email).Contains(u.Email!))
                .Select(u => new { u.Email, u.ProfilePictureUrl })
                .ToDictionaryAsync(u => u.Email!, u => u.ProfilePictureUrl, cancellationToken);

            var totalCount = patientList.Count;
            var paged      = patientList
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .Select(p => p.Adapt<PatientResponse>() with
                {
                    ProfilePictureUrl = picMap.GetValueOrDefault(p.Email)
                })
                .ToList();

            var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);
            var patients = new PagedResponse<PatientResponse>(
                paged, pageNumber, pageSize, totalCount, totalPages,
                pageNumber > 1, pageNumber < totalPages);

            return Ok(patients);
        }

        // ── NEW: GET /api/patients/relative ─────────────────────────
        // Returns all patients that have an approved RelativePatientRequest
        // for the calling relative (supports multiple linked patients).
        [HttpGet("relative")]
        [Authorize(Roles = "Relative")]
        public async Task<IActionResult> GetMyLinkedPatients(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
        {
            var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                     ?? User.FindFirst("email")?.Value;

            if (string.IsNullOrEmpty(email))
                return Unauthorized();

            var relative = await _context.Relatives
                .AsNoTracking()
                .Include(r => r.PatientRequests)
                .FirstOrDefaultAsync(r => r.Email == email, cancellationToken);

            if (relative is null)
                return NotFound(new { title = "Relative record not found." });

            var approvedPatientIds = relative.PatientRequests
                .Where(r => r.Status == "Approved")
                .Select(r => r.PatientId)
                .ToList();

            if (!approvedPatientIds.Any())
                return Ok(new { items = Array.Empty<object>(), pageNumber, pageSize, totalCount = 0, totalPages = 0 });

            var patientList = await _context.Patients
                .AsNoTracking()
                .Where(p => approvedPatientIds.Contains(p.Id))
                .OrderBy(p => p.Id)
                .ToListAsync(cancellationToken);

            var picMap = await _context.Users
                .AsNoTracking()
                .Where(u => patientList.Select(p => p.Email).Contains(u.Email!))
                .Select(u => new { u.Email, u.ProfilePictureUrl })
                .ToDictionaryAsync(u => u.Email!, u => u.ProfilePictureUrl, cancellationToken);

            var totalCount = patientList.Count;
            var paged      = patientList
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .Select(p => p.Adapt<PatientResponse>() with
                {
                    ProfilePictureUrl = picMap.GetValueOrDefault(p.Email)
                })
                .ToList();

            var totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);
            var patients = new PagedResponse<PatientResponse>(
                paged, pageNumber, pageSize, totalCount, totalPages,
                pageNumber > 1, pageNumber < totalPages);

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


        [HttpPut("{id}/bloodtype")]
             public async Task<IActionResult> UpdateBloodType(
             int id,
            [FromBody] UpdateBloodTypeRequest request,
             CancellationToken cancellationToken)
        {
            var result = await _patientService.UpdateBloodTypeAsync(
                id, request.BloodType, cancellationToken);

            return result.IsSuccess
                ? NoContent()
                : result.ToProblem();
        }

        // ── PUT /api/patients/{id}/medical-record ───────────────────
        // Allows Patient (own record), Doctor (with a FollowUp), or Admin
        // to update the medical profile fields. Only non-null fields are updated.
        [HttpPut("{id}/medical-record")]
        [Authorize(Roles = "Patient,Doctor,Admin")]
        public async Task<IActionResult> UpdateMedicalRecord(
            int id,
            [FromBody] UpdateMedicalRecordRequest request,
            CancellationToken cancellationToken)
        {
            var patient = await _context.Patients.FindAsync(new object[] { id }, cancellationToken);
            if (patient is null)
                return NotFound(new { message = "Patient not found." });

            if (User.IsInRole("Patient"))
            {
                var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                         ?? User.FindFirst("email")?.Value;
                if (patient.Email != email) return Forbid();
            }

            if (User.IsInRole("Doctor"))
            {
                var email  = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                          ?? User.FindFirst("email")?.Value;
                var doctor = await _context.Doctors.AsNoTracking()
                    .FirstOrDefaultAsync(d => d.Email == email, cancellationToken);
                if (doctor is null) return Forbid();
                var hasFollowUp = await _context.FollowUps
                    .AnyAsync(f => f.DoctorId == doctor.Id && f.PatientId == id, cancellationToken);
                if (!hasFollowUp) return Forbid();
            }

            if (request.MedicalRecord   is not null) patient.MedicalRecord   = request.MedicalRecord;
            if (request.ChronicDiseases is not null) patient.ChronicDiseases = request.ChronicDiseases;
            if (request.Allergies       is not null) patient.Allergies       = request.Allergies;
            if (request.BloodType       is not null) patient.BloodType       = request.BloodType;

            await _context.SaveChangesAsync(cancellationToken);
            return NoContent();
        }
    }
}
