using GraduationProject.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace GraduationProject.Controllers
{
    [Route("api/dispatch-requests")]
    [ApiController]
    [Authorize(Roles = "Ambulance")]
    public class DispatchRequestsController(IDispatchRequestService service) : ControllerBase
    {
        private readonly IDispatchRequestService _service = service;

        string Email() =>
            User.FindFirst("email")?.Value ??
            User.FindFirst(ClaimTypes.Email)?.Value ?? "";

        // GET /api/dispatch-requests/my
        [HttpGet("my")]
        public async Task<IActionResult> GetMy(CancellationToken cancellationToken)
        {
            var list = await _service.GetMyActiveDispatchesAsync(Email(), cancellationToken);
            return Ok(list);
        }

        // PUT /api/dispatch-requests/{id}/accept
        [HttpPut("{id}/accept")]
        public async Task<IActionResult> Accept(int id, CancellationToken cancellationToken)
        {
            var result = await _service.AcceptAsync(id, Email(), cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // PUT /api/dispatch-requests/{id}/reject
        [HttpPut("{id}/reject")]
        public async Task<IActionResult> Reject(int id, CancellationToken cancellationToken)
        {
            var result = await _service.RejectAsync(id, Email(), cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }
    }
}
