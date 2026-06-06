using GraduationProject.Contracts.LabAppointments;
using GraduationProject.Contracts.MedicalTests;
using GraduationProject.Entities;
using GraduationProject.Presistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace GraduationProject.Controllers
{
    // ════════════════════════════════════════════════════════════════
    // LabAppointmentsController
    //
    // Endpoints:
    //   GET    /api/labappointments                        — all (admin/lab)
    //   GET    /api/labappointments/patient/{patientId}    — patient's appointments
    //   GET    /api/labappointments/lab/{labId}            — lab's appointments
    //   GET    /api/labappointments/{id}                   — single
    //   POST   /api/labappointments                        — patient books
    //   PATCH  /api/labappointments/{id}/status            — lab confirms/completes
    //   DELETE /api/labappointments/{id}                   — cancel
    // ════════════════════════════════════════════════════════════════

    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class LabAppointmentsController(AppDbContext context) : ControllerBase
    {
        private readonly AppDbContext _context = context;

        private static readonly string[] ValidStatuses =
            ["Pending", "Confirmed", "Completed", "Cancelled"];

        // ── GET /api/labappointments ──────────────────────────────────────────
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 20,
            CancellationToken cancellationToken = default)
        {
            var items = await _context.LabAppointments
                .AsNoTracking()
                .Where(a => !a.IsDeleted)
                .Include(a => a.Patient)
                .Include(a => a.Lab)
                .OrderByDescending(a => a.AppointmentDate)
                .Select(a => MapToResponse(a))
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);

            return Ok(items);
        }

        // ── GET /api/labappointments/patient/{patientId} ──────────────────────
        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(
            int patientId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 20,
            CancellationToken cancellationToken = default)
        {
            var items = await _context.LabAppointments
                .AsNoTracking()
                .Where(a => a.PatientId == patientId && !a.IsDeleted)
                .Include(a => a.Patient)
                .Include(a => a.Lab)
                .OrderByDescending(a => a.AppointmentDate)
                .Select(a => MapToResponse(a))
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);

            return Ok(items);
        }

        // ── GET /api/labappointments/lab/{labId} ──────────────────────────────
        [HttpGet("lab/{labId}")]
        public async Task<IActionResult> GetByLab(
            int labId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 20,
            CancellationToken cancellationToken = default)
        {
            var items = await _context.LabAppointments
                .AsNoTracking()
                .Where(a => a.LabId == labId && !a.IsDeleted)
                .Include(a => a.Patient)
                .Include(a => a.Lab)
                .OrderByDescending(a => a.AppointmentDate)
                .Select(a => MapToResponse(a))
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);

            return Ok(items);
        }

        // ── GET /api/labappointments/{id} ─────────────────────────────────────
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(
            int id,
            CancellationToken cancellationToken)
        {
            var a = await _context.LabAppointments
                .AsNoTracking()
                .Include(x => x.Patient)
                .Include(x => x.Lab)
                .FirstOrDefaultAsync(x => x.Id == id && !x.IsDeleted, cancellationToken);

            if (a is null)
                return NotFound(new { message = "Appointment not found." });

            return Ok(MapToResponse(a));
        }

        // ── POST /api/labappointments ─────────────────────────────────────────
        [HttpPost]
        public async Task<IActionResult> Create(
            LabAppointmentRequest request,
            CancellationToken cancellationToken)
        {
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return NotFound(new { message = "Patient not found." });

            var labExists = await _context.Labs
                .AnyAsync(l => l.Id == request.LabId, cancellationToken);

            if (!labExists)
                return NotFound(new { message = "Lab not found." });

            var appointment = new LabAppointment
            {
                PatientId       = request.PatientId,
                LabId           = request.LabId,
                TestNames       = string.Join(",", request.TestNames),
                AppointmentDate = request.AppointmentDate,
                Notes           = request.Notes ?? string.Empty,
                Status          = "Pending",
                CreatedAt       = DateTime.UtcNow
            };

            await _context.LabAppointments.AddAsync(appointment, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            // Reload with navigation properties
            await _context.Entry(appointment).Reference(a => a.Patient).LoadAsync(cancellationToken);
            await _context.Entry(appointment).Reference(a => a.Lab).LoadAsync(cancellationToken);

            return CreatedAtAction(nameof(GetById),
                new { id = appointment.Id },
                MapToResponse(appointment));
        }

        // ── PATCH /api/labappointments/{id}/status ────────────────────────────
        [HttpPatch("{id}/status")]
        public async Task<IActionResult> UpdateStatus(
            int id,
            [FromBody] UpdateLabAppointmentStatusRequest request,
            CancellationToken cancellationToken)
        {
            if (!ValidStatuses.Contains(request.Status))
                return BadRequest(new { message = $"Status must be one of: {string.Join(", ", ValidStatuses)}" });

            var appointment = await _context.LabAppointments
                .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted, cancellationToken);

            if (appointment is null)
                return NotFound(new { message = "Appointment not found." });

            appointment.Status = request.Status;
            await _context.SaveChangesAsync(cancellationToken);

            return NoContent();
        }

        [HttpPost("{id}/complete")]
        public async Task<IActionResult> Complete(
            int id,
            [FromBody] CompleteLabAppointmentRequest request,
            CancellationToken cancellationToken)
        {
            if (request.Results is null || request.Results.Count == 0)
                return BadRequest(new { message = "At least one test result is required." });

            if (request.Results.Any(r =>
                    string.IsNullOrWhiteSpace(r.Name) ||
                    string.IsNullOrWhiteSpace(r.Result)))
                return BadRequest(new { message = "Each result must include a test name and result." });

            var appointment = await _context.LabAppointments
                .Include(a => a.Patient)
                .Include(a => a.Lab)
                .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted, cancellationToken);

            if (appointment is null)
                return NotFound(new { message = "Appointment not found." });

            if (appointment.Status == "Cancelled")
                return BadRequest(new { message = "Cancelled appointments cannot be completed." });

            if (appointment.Status == "Completed")
                return BadRequest(new { message = "Appointment is already completed." });

            var now = DateTime.UtcNow;
            var tests = request.Results.Select(r => new MedicalTest
            {
                Name = r.Name.Trim(),
                Result = r.Result.Trim(),
                PatientId = appointment.PatientId,
                LabId = appointment.LabId,
                Date = now
            }).ToList();

            await _context.MedicalTests.AddRangeAsync(tests, cancellationToken);
            appointment.Status = "Completed";

            await _context.SaveChangesAsync(cancellationToken);

            var response = tests.Select(t => new MedicalTestResponse(
                t.Id,
                t.Name,
                t.Result,
                t.Date,
                t.PatientId,
                t.LabId,
                t.ImagePath is null ? null : $"/{t.ImagePath}"
            )).ToList();

            return Ok(response);
        }

        // ── DELETE /api/labappointments/{id} ──────────────────────────────────
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(
            int id,
            CancellationToken cancellationToken)
        {
            var appointment = await _context.LabAppointments
                .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted, cancellationToken);

            if (appointment is null)
                return NotFound(new { message = "Appointment not found." });

            appointment.IsDeleted    = true;
            appointment.DeletedAtUtc = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);

            return NoContent();
        }

        // ── Private mapper ────────────────────────────────────────────────────
        private static LabAppointmentResponse MapToResponse(LabAppointment a) =>
            new(
                a.Id,
                a.PatientId,
                a.Patient?.Name ?? string.Empty,
                a.LabId,
                a.Lab?.Name ?? string.Empty,
                a.TestNames.Split(',', StringSplitOptions.RemoveEmptyEntries).ToList(),
                a.AppointmentDate,
                a.Notes,
                a.Status,
                a.CreatedAt
            );
    }
}
