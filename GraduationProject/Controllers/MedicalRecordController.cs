using GraduationProject.Contracts.MedicalRecord;
using GraduationProject.Contracts.Patients;

namespace GraduationProject.Controllers
{
    [Route("api/medical-record")]
    [ApiController]
    [Authorize]
    public class MedicalRecordController(
        IMedicalRecordService service,
        AppDbContext context) : ControllerBase
    {
        private readonly IMedicalRecordService _service = service;
        private readonly AppDbContext          _context = context;

        // GET /api/medical-record/{patientId}/history
        [HttpGet("{patientId}/history")]
        public async Task<IActionResult> GetHistory(
            int patientId,
            CancellationToken cancellationToken)
        {
            if (!await CanAccessAsync(patientId, cancellationToken))
                return Forbid();

            return Ok(await _service.GetHistoryAsync(patientId, cancellationToken));
        }

        // PUT /api/medical-record/{patientId}
        // Doctors can update only patients they have a follow-up with.
        // Patients can update their own record.
        [HttpPut("{patientId}")]
        [Authorize(Roles = "Doctor,Patient,Admin")]
        public async Task<IActionResult> Update(
            int patientId,
            [FromBody] UpdateMedicalRecordRequest request,
            CancellationToken cancellationToken)
        {
            var email = GetEmail();
            var role  = GetRole();

            if (role == "Doctor")
            {
                var doctor = await _context.Doctors
                    .AsNoTracking()
                    .FirstOrDefaultAsync(d => d.Email == email, cancellationToken);

                if (doctor is null) return Forbid();

                var hasFollowUp = await _context.FollowUps
                    .AnyAsync(f => f.DoctorId == doctor.Id &&
                                   f.PatientId == patientId, cancellationToken);

                if (!hasFollowUp) return Forbid();
            }
            else if (role == "Patient")
            {
                var isOwner = await _context.Patients
                    .AnyAsync(p => p.Id == patientId && p.Email == email, cancellationToken);

                if (!isOwner) return Forbid();
            }

            var authorName = await ResolveAuthorNameAsync(email, role, cancellationToken);
            var result = await _service.AddEntryAsync(
                patientId, email, authorName, role, request, cancellationToken);

            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // ── Helpers ───────────────────────────────────────────────────

        private string GetEmail() =>
            User.FindFirst("email")?.Value ??
            User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? "";

        private string GetRole() =>
            User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value ??
            User.FindFirst("role")?.Value ?? "";

        private async Task<bool> CanAccessAsync(int patientId, CancellationToken ct)
        {
            var role  = GetRole();
            var email = GetEmail();

            return role switch
            {
                "Admin"    => true,
                "Patient"  => await _context.Patients
                                  .AnyAsync(p => p.Id == patientId && p.Email == email, ct),
                "Doctor"   => await _context.FollowUps
                                  .AnyAsync(f => f.PatientId == patientId &&
                                      _context.Doctors.Any(d => d.Email == email && d.Id == f.DoctorId), ct),
                "Relative" => await _context.Relatives
                                  .AsNoTracking()
                                  .Include(r => r.PatientRequests)
                                  .AnyAsync(r => r.Email == email &&
                                      r.PatientRequests.Any(req =>
                                          req.PatientId == patientId && req.Status == "Approved"), ct),
                _ => false,
            };
        }

        private async Task<string> ResolveAuthorNameAsync(
            string email, string role, CancellationToken ct) => role switch
        {
            "Doctor"  => await _context.Doctors
                             .Where(d => d.Email == email)
                             .Select(d => d.Name)
                             .FirstOrDefaultAsync(ct) ?? email,
            "Patient" => await _context.Patients
                             .Where(p => p.Email == email)
                             .Select(p => p.Name)
                             .FirstOrDefaultAsync(ct) ?? email,
            _ => email,
        };
    }
}
