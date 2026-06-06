using GraduationProject.Contracts.PatientProgress;
using GraduationProject.Presistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class PatientProgressController(AppDbContext context) : ControllerBase
    {
        private readonly AppDbContext _context = context;

        [HttpGet("{patientId:int}")]
        public async Task<IActionResult> GetPatientProgress(
            int patientId,
            [FromQuery] DateTime? from = null,
            [FromQuery] DateTime? to = null,
            [FromQuery] int limit = 100,
            CancellationToken cancellationToken = default)
        {
            if (limit is < 1 or > 500)
                return BadRequest(new { message = "Limit must be between 1 and 500." });

            if (from.HasValue && to.HasValue && from > to)
                return BadRequest(new { message = "'from' must be before 'to'." });

            var patient = await _context.Patients
                .AsNoTracking()
                .Where(p => p.Id == patientId)
                .Select(p => new { p.Id, p.Name })
                .FirstOrDefaultAsync(cancellationToken);

            if (patient is null)
                return NotFound(new { message = "Patient not found." });

            var query = _context.VitalSigns
                .AsNoTracking()
                .Where(v => v.PatientId == patientId);

            if (from.HasValue)
                query = query.Where(v => v.TimeStamp >= from.Value);

            if (to.HasValue)
                query = query.Where(v => v.TimeStamp <= to.Value);

            var readings = await query
                .OrderByDescending(v => v.TimeStamp)
                .Take(limit)
                .OrderBy(v => v.TimeStamp)
                .Select(v => new PatientProgressPointResponse(
                    v.TimeStamp,
                    v.HeartRate,
                    v.OxygenSaturation,
                    v.EmergencyStatus
                ))
                .ToListAsync(cancellationToken);

            var summary = readings.Count == 0
                ? new PatientProgressSummaryResponse(0, 0, 0, 0, 0, 0, 0, 0)
                : new PatientProgressSummaryResponse(
                    readings.Count,
                    Math.Round(readings.Average(r => r.HeartRate), 2),
                    Math.Round(readings.Average(r => r.OxygenSaturation), 2),
                    readings.Min(r => r.HeartRate),
                    readings.Max(r => r.HeartRate),
                    readings.Min(r => r.OxygenSaturation),
                    readings.Max(r => r.OxygenSaturation),
                    readings.Count(r => r.EmergencyStatus)
                );

            return Ok(new PatientProgressResponse(
                patient.Id,
                patient.Name,
                from,
                to,
                summary,
                readings
            ));
        }
    }
}
