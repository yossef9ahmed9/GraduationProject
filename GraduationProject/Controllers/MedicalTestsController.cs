using GraduationProject.Contracts.MedicalTests;
using GraduationProject.Presistence;
using GraduationProject.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class MedicalTestsController(
        IMedicalTestService service,
        AppDbContext context) : ControllerBase
    {
        private readonly IMedicalTestService _service = service;
        private readonly AppDbContext        _context = context;

        string Email() =>
            User.FindFirst("email")?.Value ??
            User.FindFirst(ClaimTypes.Email)?.Value ?? "";

        // GET /api/medicaltests
        [HttpGet]
        public async Task<IActionResult> Get(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
        {
            if (User.IsInRole("Patient"))
            {
                var patient = await _context.Patients.AsNoTracking()
                    .FirstOrDefaultAsync(p => p.Email == Email(), cancellationToken);
                if (patient is null) return Unauthorized();
                return Ok(await _service.GetByPatientAsync(patient.Id, pageNumber, pageSize, cancellationToken));
            }

            if (User.IsInRole("Lab"))
            {
                var lab = await _context.Labs.AsNoTracking()
                    .FirstOrDefaultAsync(l => l.Email == Email(), cancellationToken);
                if (lab is null) return Unauthorized();
                return Ok(await _service.GetByLabAsync(lab.Id, pageNumber, pageSize, cancellationToken));
            }

            if (User.IsInRole("Relative"))
            {
                var relative = await _context.Relatives.AsNoTracking()
                    .FirstOrDefaultAsync(r => r.Email == Email(), cancellationToken);
                if (relative?.PatientId is null)
                    return Ok(new { items = Array.Empty<object>() });
                return Ok(await _service.GetByPatientAsync(
                    relative.PatientId.Value, pageNumber, pageSize, cancellationToken));
            }

            if (User.IsInRole("Doctor"))
            {
                var doctor = await _context.Doctors.AsNoTracking()
                    .FirstOrDefaultAsync(d => d.Email == Email(), cancellationToken);
                if (doctor is null) return Unauthorized();

                var patientIds = await _context.FollowUps.AsNoTracking()
                    .Where(f => f.DoctorId == doctor.Id)
                    .Select(f => f.PatientId)
                    .Distinct()
                    .ToListAsync(cancellationToken);

                return Ok(await _service.GetByPatientIdsAsync(
                    patientIds, pageNumber, pageSize, cancellationToken));
            }

            // Admin — all
            return Ok(await _service.GetAllAsync(pageNumber, pageSize, cancellationToken));
        }

        // GET /api/medicaltests/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id, CancellationToken cancellationToken)
        {
            var result = await _service.GetAsync(id, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // GET /api/medicaltests/patient/{patientId}
        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(
            int patientId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
            => Ok(await _service.GetByPatientAsync(patientId, pageNumber, pageSize, cancellationToken));

        // GET /api/medicaltests/lab/{labId}
        [HttpGet("lab/{labId}")]
        public async Task<IActionResult> GetByLab(
            int labId,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
            => Ok(await _service.GetByLabAsync(labId, pageNumber, pageSize, cancellationToken));

        // POST /api/medicaltests
        [HttpPost]
        public async Task<IActionResult> Create(
            MedicalTestRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _service.AddAsync(request, cancellationToken);
            return result.IsSuccess
                ? CreatedAtAction(nameof(GetById), new { id = result.Value.Id }, result.Value)
                : result.ToProblem();
        }

        // PUT /api/medicaltests/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(
            int id,
            MedicalTestRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _service.UpdateAsync(id, request, cancellationToken);
            return result.IsSuccess ? NoContent() : result.ToProblem();
        }

        // DELETE /api/medicaltests/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
        {
            var result = await _service.DeleteAsync(id, cancellationToken);
            return result.IsSuccess ? NoContent() : result.ToProblem();
        }
    }
}
