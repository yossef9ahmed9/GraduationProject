using GraduationProject.Contracts.RelativeRequests;
using GraduationProject.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace GraduationProject.Controllers
{
    [Route("api/relative-requests")]
    [ApiController]
    [Authorize]
    public class RelativePatientRequestsController(IRelativeRequestService service) : ControllerBase
    {
        private readonly IRelativeRequestService _service = service;

        string Email() =>
            User.FindFirst("email")?.Value ??
            User.FindFirst(ClaimTypes.Email)?.Value ?? "";

        // POST /api/relative-requests
        [HttpPost]
        [Authorize(Roles = "Relative")]
        public async Task<IActionResult> Send(
            [FromBody] SendRelativeRequestRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _service.SendRequestAsync(Email(), request.PatientId, cancellationToken);
            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // GET /api/relative-requests/patient/me
        [HttpGet("patient/me")]
        [Authorize(Roles = "Patient")]
        public async Task<IActionResult> GetForPatient(CancellationToken cancellationToken)
        {
            var list = await _service.GetRequestsForPatientAsync(Email(), cancellationToken);
            return Ok(list);
        }

        // GET /api/relative-requests/my-status
        [HttpGet("my-status")]
        [Authorize(Roles = "Relative")]
        public async Task<IActionResult> GetMyStatus(CancellationToken cancellationToken)
        {
            var list = await _service.GetMyRequestStatusAsync(Email(), cancellationToken);
            return Ok(list);
        }

        // PUT /api/relative-requests/{id}/approve
        [HttpPut("{id}/approve")]
        [Authorize(Roles = "Patient")]
        public async Task<IActionResult> Approve(int id, CancellationToken cancellationToken)
        {
            var result = await _service.ApproveAsync(id, Email(), cancellationToken);
            return result.IsSuccess ? NoContent() : result.ToProblem();
        }

        // PUT /api/relative-requests/{id}/reject
        [HttpPut("{id}/reject")]
        [Authorize(Roles = "Patient")]
        public async Task<IActionResult> Reject(int id, CancellationToken cancellationToken)
        {
            var result = await _service.RejectAsync(id, Email(), cancellationToken);
            return result.IsSuccess ? NoContent() : result.ToProblem();
        }

        // GET /api/relative-requests/search-patients?q=
        [HttpGet("search-patients")]
        [Authorize(Roles = "Relative")]
        public async Task<IActionResult> SearchPatients(
            [FromQuery] string q,
            CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(q) || q.Length < 2)
                return BadRequest(new { message = "Query must be at least 2 characters." });

            var results = await _service.SearchPatientsAsync(q, cancellationToken);
            return Ok(results);
        }
    }
}
