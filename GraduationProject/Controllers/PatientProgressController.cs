using GraduationProject.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace GraduationProject.Controllers
{
    [Route("api/patient-progress")]
    [ApiController]
    [Authorize]
    public class PatientProgressController(IPatientProgressService service) : ControllerBase
    {
        private readonly IPatientProgressService _service = service;

        string Email() =>
            User.FindFirst("email")?.Value ??
            User.FindFirst(ClaimTypes.Email)?.Value ?? "";

        string Role() =>
            User.FindFirst(ClaimTypes.Role)?.Value ??
            User.FindFirst("role")?.Value ?? "";

        // GET /api/patient-progress/{patientId}
        [HttpGet("{patientId}")]
        public async Task<IActionResult> Get(int patientId, CancellationToken cancellationToken)
        {
            var result = await _service.GetProgressAsync(
                patientId, Email(), Role(), cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }
    }
}
