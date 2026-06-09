namespace GraduationProject.Controllers
{
    [Route("api/patient-file")]
    [ApiController]
    [Authorize]
    public class PatientFileController(AppDbContext context) : ControllerBase
    {
        private readonly AppDbContext _context = context;

        // GET /api/patient-file/{patientId}
        // Returns everything needed to render the Patient File page in one call:
        // patient info, medical record history, prescriptions (from follow-ups),
        // last 200 vitals, and last 100 lab tests.
        [HttpGet("{patientId}")]
        public async Task<IActionResult> Get(
            int patientId,
            CancellationToken cancellationToken)
        {
            var email = GetEmail();
            var role  = GetRole();

            if (!await CanAccessAsync(patientId, email, role, cancellationToken))
                return Forbid();

            var patient = await _context.Patients
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == patientId, cancellationToken);

            if (patient is null)
                return NotFound(new { message = "Patient not found." });

            var vitals = await _context.VitalSigns
                .AsNoTracking()
                .Where(v => v.PatientId == patientId)
                .OrderByDescending(v => v.TimeStamp)
                .Take(200)
                .Select(v => new
                {
                    v.Id,
                    v.HeartRate,
                    v.OxygenSaturation,
                    v.EmergencyStatus,
                    v.TimeStamp,
                })
                .ToListAsync(cancellationToken);

            var recordHistory = await _context.MedicalRecordEntries
                .AsNoTracking()
                .Where(e => e.PatientId == patientId)
                .OrderByDescending(e => e.CreatedAt)
                .Select(e => new
                {
                    e.Id,
                    e.AuthorName,
                    e.AuthorEmail,
                    e.AuthorRole,
                    e.MedicalRecord,
                    e.ChronicDiseases,
                    e.Allergies,
                    e.BloodType,
                    e.CreatedAt,
                })
                .ToListAsync(cancellationToken);

            // Prescriptions = approved follow-ups that have a real treatment plan
            var prescriptions = await _context.FollowUps
                .AsNoTracking()
                .Include(f => f.Doctor)
                .Where(f => f.PatientId == patientId &&
                            f.Status    == "Approved" &&
                            f.TreatmentPlan != null &&
                            f.TreatmentPlan != "To be determined")
                .OrderByDescending(f => f.LastUpdate)
                .Select(f => new
                {
                    f.Id,
                    DoctorName     = f.Doctor.Name,
                    DoctorEmail    = f.Doctor.Email,
                    Specialization = f.Doctor.Specialization,
                    f.Diagnosis,
                    f.TreatmentPlan,
                    f.Notes,
                    f.Severity,
                    f.LastUpdate,
                    f.NextVisitDate,
                })
                .ToListAsync(cancellationToken);

            var labTests = await _context.MedicalTests
                .AsNoTracking()
                .Include(t => t.Lab)
                .Where(t => t.PatientId == patientId)
                .OrderByDescending(t => t.Date)
                .Take(100)
                .Select(t => new
                {
                    t.Id,
                    t.Name,
                    t.Result,
                    t.Date,
                    LabName = t.Lab.Name,
                    t.LabId,
                })
                .ToListAsync(cancellationToken);

            return Ok(new
            {
                patientId       = patient.Id,
                patientName     = patient.Name,
                bloodType       = patient.BloodType,
                medicalRecord   = patient.MedicalRecord,
                chronicDiseases = patient.ChronicDiseases,
                allergies       = patient.Allergies,
                vitals,
                recordHistory,
                prescriptions,
                labTests,
            });
        }

        private string GetEmail() =>
            User.FindFirst("email")?.Value ??
            User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? "";

        private string GetRole() =>
            User.FindFirst(System.Security.Claims.ClaimTypes.Role)?.Value ??
            User.FindFirst("role")?.Value ?? "";

        private async Task<bool> CanAccessAsync(
            int patientId, string email, string role, CancellationToken ct) => role switch
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
}
