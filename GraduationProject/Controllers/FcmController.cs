using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace GraduationProject.Controllers
{
    // ════════════════════════════════════════════════════════════════
    // FcmController
    //
    // Endpoints:
    //   POST /api/fcm/register  — save device FCM token for push notifications
    // ════════════════════════════════════════════════════════════════

    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class FcmController(IFcmService fcmService) : ControllerBase
    {
        private readonly IFcmService _fcmService = fcmService;

        // POST /api/fcm/register
        // Call this from Flutter after login, passing the Firebase token
        [HttpPost("register")]
        public async Task<IActionResult> Register(
            [FromBody] RegisterFcmTokenRequest request,
            CancellationToken cancellationToken)
        {
            if (string.IsNullOrWhiteSpace(request.FcmToken))
                return BadRequest(new { message = "FCM token is required." });

            await _fcmService.RegisterFcmTokenAsync(
                request.UserEmail,
                request.FcmToken,
                cancellationToken);

            return Ok(new { message = "FCM token registered." });
        }
    }

    public record RegisterFcmTokenRequest(
        string UserEmail,
        string FcmToken
    );
}
