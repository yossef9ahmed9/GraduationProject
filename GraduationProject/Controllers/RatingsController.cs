using GraduationProject.Contracts.Ratings;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class RatingsController(IRatingService service) : ControllerBase
    {
        private readonly IRatingService _service = service;

        /// <summary>
        /// Submit or update the current patient's rating for a doctor or lab.
        /// Body: { stars: 4, doctorId: 7 }  OR  { stars: 3, labId: 2 }
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> Submit(
            [FromBody] RatingRequest request,
            CancellationToken cancellationToken)
        {
            var email  = User.FindFirst(ClaimTypes.Email)?.Value
                      ?? User.FindFirst("email")?.Value
                      ?? string.Empty;

            var result = await _service.SubmitAsync(email, request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        /// <summary>
        /// Get the current patient's own rating for a doctor or lab.
        /// Query: ?doctorId=7  OR  ?labId=2
        /// </summary>
        [HttpGet("my")]
        public async Task<IActionResult> GetMy(
            [FromQuery] int? doctorId,
            [FromQuery] int? labId,
            CancellationToken cancellationToken)
        {
            var email  = User.FindFirst(ClaimTypes.Email)?.Value
                      ?? User.FindFirst("email")?.Value
                      ?? string.Empty;

            var result = await _service.GetMyRatingAsync(email, doctorId, labId, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }
    }
}
