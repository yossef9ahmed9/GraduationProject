using GraduationProject.Contracts.Ambulances;
using GraduationProject.Presistence;
using Mapster;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace GraduationProject.Controllers
{
    // ════════════════════════════════════════════════════════════════
    // AmbulancesController
    //
    // Endpoints:
    //   GET    /api/ambulances                        — all ambulances (paged)
    //   GET    /api/ambulances/available              — only Available ones
    //   GET    /api/ambulances/{id}                   — single ambulance
    //   GET    /api/ambulances/{id}/dispatches        — dispatch history for ambulance
    //   PUT    /api/ambulances/{id}/availability      — update availability status
    // ════════════════════════════════════════════════════════════════

    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AmbulancesController(AppDbContext context) : ControllerBase
    {
        private readonly AppDbContext _context = context;

        // ── GET /api/ambulances ───────────────────────────────────────────────
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 20,
            CancellationToken cancellationToken = default)
        {
            var query = _context.Ambulances
                .AsNoTracking()
                .Where(a => !a.IsDeleted);

            if (User.IsInRole("Ambulance"))
            {
                var email = GetUserEmail();
                if (string.IsNullOrWhiteSpace(email))
                    return Unauthorized(new { message = "Ambulance email claim is missing." });

                var name = GetUserName();
                query = query.Where(a =>
                    a.Email == email ||
                    (a.Email == "" && a.StationName == name));
            }

            var ambulances = await query
                .OrderBy(a => a.StationName)
                .Select(a => new AmbulanceResponse(
                    a.Id,
                    a.Email,
                    a.StationName,
                    a.Phone,
                    a.AvailabilityStatus,
                    a.LicensePlate,
                    a.DriverName,
                    a.DriverPhone,
                    a.Latitude,
                    a.Longitude,
                    a.LastLocationUpdate,
                    a.EmergencyDispatches
                        .Count(d => d.Status != "Resolved" && d.Status != "Cancelled")
                ))
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);

            return Ok(ambulances);
        }

        // ── GET /api/ambulances/available ─────────────────────────────────────
        [HttpGet("available")]
        public async Task<IActionResult> GetAvailable(
            CancellationToken cancellationToken = default)
        {
            var query = _context.Ambulances
                .AsNoTracking()
                .Where(a => !a.IsDeleted && a.AvailabilityStatus == "Available");

            if (User.IsInRole("Ambulance"))
            {
                var email = GetUserEmail();
                if (string.IsNullOrWhiteSpace(email))
                    return Unauthorized(new { message = "Ambulance email claim is missing." });

                var name = GetUserName();
                query = query.Where(a =>
                    a.Email == email ||
                    (a.Email == "" && a.StationName == name));
            }

            var ambulances = await query
                .OrderBy(a => a.StationName)
                .Select(a => new AmbulanceResponse(
                    a.Id,
                    a.Email,
                    a.StationName,
                    a.Phone,
                    a.AvailabilityStatus,
                    a.LicensePlate,
                    a.DriverName,
                    a.DriverPhone,
                    a.Latitude,
                    a.Longitude,
                    a.LastLocationUpdate,
                    0
                ))
                .ToListAsync(cancellationToken);

            return Ok(ambulances);
        }

        // ── GET /api/ambulances/{id} ──────────────────────────────────────────
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(
            int id,
            CancellationToken cancellationToken)
        {
            var ambulance = await _context.Ambulances
                .AsNoTracking()
                .Where(a => a.Id == id && !a.IsDeleted)
                .Select(a => new AmbulanceResponse(
                    a.Id,
                    a.Email,
                    a.StationName,
                    a.Phone,
                    a.AvailabilityStatus,
                    a.LicensePlate,
                    a.DriverName,
                    a.DriverPhone,
                    a.Latitude,
                    a.Longitude,
                    a.LastLocationUpdate,
                    a.EmergencyDispatches
                        .Count(d => d.Status != "Resolved" && d.Status != "Cancelled")
                ))
                .FirstOrDefaultAsync(cancellationToken);

            if (ambulance is null)
                return NotFound(new { message = "Ambulance not found." });

            if (User.IsInRole("Ambulance"))
            {
                var email = GetUserEmail();
                if (string.IsNullOrWhiteSpace(email))
                    return Unauthorized(new { message = "Ambulance email claim is missing." });

                var name = GetUserName();
                var isOwnAmbulance = ambulance.Email == email ||
                    (ambulance.Email == "" && ambulance.StationName == name);

                if (!isOwnAmbulance)
                    return Forbid();
            }

            return Ok(ambulance);
        }

        // ── GET /api/ambulances/{id}/dispatches ───────────────────────────────
        [HttpGet("{id}/dispatches")]
        public async Task<IActionResult> GetDispatches(
            int id,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
        {
            var exists = await _context.Ambulances
                .AnyAsync(a => a.Id == id && !a.IsDeleted, cancellationToken);

            if (!exists)
                return NotFound(new { message = "Ambulance not found." });

            if (User.IsInRole("Ambulance"))
            {
                var email = GetUserEmail();
                if (string.IsNullOrWhiteSpace(email))
                    return Unauthorized(new { message = "Ambulance email claim is missing." });

                var name = GetUserName();
                var isOwnAmbulance = await _context.Ambulances.AnyAsync(a =>
                    a.Id == id &&
                    !a.IsDeleted &&
                    (a.Email == email || (a.Email == "" && a.StationName == name)),
                    cancellationToken);

                if (!isOwnAmbulance)
                    return Forbid();
            }

            var dispatches = await _context.EmergencyDispatches
                .AsNoTracking()
                .Where(d => d.AmbulanceId == id)
                .OrderByDescending(d => d.DispatchedAt)
                .Select(d => new
                {
                    d.Id,
                    d.DispatchedAt,
                    d.ArrivedAt,
                    d.ResolvedAt,
                    d.Status,
                    d.PatientId,
                    PatientName = d.Patient.Name,
                    d.Notes
                })
                .ToPagedListAsync(pageNumber, pageSize, cancellationToken);

            return Ok(dispatches);
        }

        // ── PUT /api/ambulances/{id}/availability ─────────────────────────────
        // Ambulance driver can update their own status manually
        [HttpPut("{id}/availability")]
        public async Task<IActionResult> UpdateAvailability(
            int id,
            [FromBody] UpdateAmbulanceAvailabilityRequest request,
            CancellationToken cancellationToken)
        {
            var valid = new[] { "Available", "Busy", "OutOfService" };
            if (!valid.Contains(request.AvailabilityStatus))
                return BadRequest(new { message = "Status must be Available, Busy, or OutOfService." });

            var ambulance = await _context.Ambulances
                .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted, cancellationToken);

            if (ambulance is null)
                return NotFound(new { message = "Ambulance not found." });

            if (User.IsInRole("Ambulance"))
            {
                var email = GetUserEmail();
                if (string.IsNullOrWhiteSpace(email))
                    return Unauthorized(new { message = "Ambulance email claim is missing." });

                var name = GetUserName();
                var isOwnAmbulance = ambulance.Email == email ||
                    (ambulance.Email == "" && ambulance.StationName == name);

                if (!isOwnAmbulance)
                    return Forbid();

                if (string.IsNullOrWhiteSpace(ambulance.Email))
                    ambulance.Email = email;
            }

            ambulance.AvailabilityStatus = request.AvailabilityStatus;
            await _context.SaveChangesAsync(cancellationToken);

            return NoContent();
        }

        private string? GetUserEmail() =>
            User.FindFirstValue(ClaimTypes.Email)
            ?? User.FindFirstValue("email");

        private string? GetUserName() =>
            User.FindFirstValue(ClaimTypes.Name)
            ?? User.FindFirstValue(JwtRegisteredClaimNames.Name)
            ?? User.FindFirstValue("name");
    }
}
