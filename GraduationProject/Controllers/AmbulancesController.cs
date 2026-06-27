using GraduationProject.Contracts.Ambulances;
using GraduationProject.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AmbulancesController(IAmbulanceService service) : ControllerBase
    {
        private readonly IAmbulanceService _service = service;

        string Email() =>
            User.FindFirst("email")?.Value ??
            User.FindFirst(ClaimTypes.Email)?.Value ?? "";

        bool IsAmbulance() => User.IsInRole("Ambulance");

        // GET /api/ambulances
        [HttpGet]
        public async Task<IActionResult> GetAll(
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 20,
            CancellationToken cancellationToken = default)
        {
            var result = await _service.GetAllAsync(
                Email(), IsAmbulance(), pageNumber, pageSize, cancellationToken);
            return Ok(result);
        }

        // GET /api/ambulances/available
        [HttpGet("available")]
        public async Task<IActionResult> GetAvailable(CancellationToken cancellationToken)
            => Ok(await _service.GetAvailableAsync(cancellationToken));

        // GET /api/ambulances/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id, CancellationToken cancellationToken)
        {
            var result = await _service.GetByIdAsync(id, Email(), IsAmbulance(), cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // GET /api/ambulances/{id}/dispatches
        [HttpGet("{id}/dispatches")]
        public async Task<IActionResult> GetDispatches(
            int id,
            [FromQuery] int pageNumber = 1,
            [FromQuery] int pageSize   = 10,
            CancellationToken cancellationToken = default)
        {
            var result = await _service.GetDispatchesAsync(
                id, Email(), IsAmbulance(), pageNumber, pageSize, cancellationToken);
            return Ok(result);
        }

        // PUT /api/ambulances/{id}/availability
        [HttpPut("{id}/availability")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> UpdateAvailability(
            int id,
            [FromBody] UpdateAmbulanceAvailabilityRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _service.UpdateAvailabilityAsync(
                id, request.AvailabilityStatus, Email(), IsAmbulance(), cancellationToken);
            return result.IsSuccess ? NoContent() : result.ToProblem();
        }

        // GET /api/ambulances/me — returns the ambulance record for the logged-in driver
        [HttpGet("me")]
        [Authorize(Roles = "Ambulance")]
        public async Task<IActionResult> GetMe(CancellationToken cancellationToken)
        {
            var result = await _service.GetByEmailAsync(Email(), cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // POST /api/ambulances/signin
        [HttpPost("signin")]
        [Authorize(Roles = "Ambulance")]
        public async Task<IActionResult> SignIn(CancellationToken cancellationToken)
        {
            var result = await _service.SignInAsync(Email(), cancellationToken);
            return result.IsSuccess
                ? Ok(new { message = "Status set to Available." })
                : result.ToProblem();
        }

        // POST /api/ambulances/signout
        [HttpPost("signout")]
        [Authorize(Roles = "Ambulance")]
        public async Task<IActionResult> SignOut(CancellationToken cancellationToken)
        {
            var result = await _service.SignOutAsync(Email(), cancellationToken);
            return result.IsSuccess
                ? Ok(new { message = "Status set to NotAvailable." })
                : result.ToProblem();
        }
    }
}
