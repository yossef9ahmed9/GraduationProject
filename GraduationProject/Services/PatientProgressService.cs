using GraduationProject.Contracts.PatientProgress;
using GraduationProject.Presistence;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Services
{
    public class PatientProgressService(AppDbContext context) : IPatientProgressService
    {
        private readonly AppDbContext _context = context;

        public async Task<Result<PatientProgressResponse>> GetProgressAsync(
            int patientId,
            string callerEmail,
            string callerRole,
            CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == patientId, cancellationToken);

            if (patient is null)
                return Result.Failure<PatientProgressResponse>(new Error(
                    "Progress.PatientNotFound",
                    "Patient not found.",
                    StatusCodes.Status404NotFound));

            // Access control
            var allowed = callerRole switch
            {
                "Patient"  => string.Equals(patient.Email, callerEmail,
                                  StringComparison.OrdinalIgnoreCase),
                "Doctor"   => await _context.Doctors.AsNoTracking()
                                  .AnyAsync(d => d.Email == callerEmail &&
                                      _context.FollowUps.Any(f =>
                                          f.DoctorId == d.Id &&
                                          f.PatientId == patientId),
                                      cancellationToken),
                "Relative" => await _context.Relatives.AsNoTracking()
                                  .Include(r => r.PatientRequests)
                                  .AnyAsync(r => r.Email == callerEmail &&
                                      r.PatientRequests.Any(req =>
                                          req.PatientId == patientId &&
                                          req.Status == "Approved"),
                                      cancellationToken),
                _ => true  // Admin, Lab
            };

            if (!allowed)
                return Result.Failure<PatientProgressResponse>(new Error(
                    "Progress.Forbidden",
                    "You are not authorised to view this patient's progress.",
                    StatusCodes.Status403Forbidden));

            // Vitals — last 200 points
            var vitals = await _context.VitalSigns
                .AsNoTracking()
                .Where(v => v.PatientId == patientId)
                .OrderByDescending(v => v.TimeStamp)
                .Take(200)
                .Select(v => new PatientProgressPointResponse(
                    v.TimeStamp,
                    v.HeartRate,
                    v.OxygenSaturation,
                    v.EmergencyStatus))
                .ToListAsync(cancellationToken);

            var summary = vitals.Count == 0
                ? new PatientProgressSummaryResponse(0, 0, 0, 0, 0, 0, 0, 0)
                : new PatientProgressSummaryResponse(
                    vitals.Count,
                    Math.Round(vitals.Average(r => r.HeartRate), 2),
                    Math.Round(vitals.Average(r => r.OxygenSaturation), 2),
                    vitals.Min(r => r.HeartRate),
                    vitals.Max(r => r.HeartRate),
                    vitals.Min(r => r.OxygenSaturation),
                    vitals.Max(r => r.OxygenSaturation),
                    vitals.Count(r => r.EmergencyStatus));

            // Tests — last 100
            var tests = await _context.MedicalTests
                .AsNoTracking()
                .Where(t => t.PatientId == patientId)
                .OrderByDescending(t => t.Date)
                .Take(100)
                .Select(t => new MedicalTestPoint(
                    t.Date, t.Name, t.Result, t.LabId, t.Lab.Name))
                .ToListAsync(cancellationToken);

            return Result.Success(new PatientProgressResponse(
                patient.Id,
                patient.Name,
                null,
                null,
                summary,
                vitals.AsReadOnly(),
                tests.AsReadOnly()));
        }
    }
}
