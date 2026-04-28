namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController(IAuthService authenticationService)
        : ControllerBase
    {
        public IAuthService _authenticationService = authenticationService;

        [HttpPost("login")]
        public async Task<IActionResult> LoginAsync(
            LoginRequest request,
            CancellationToken cancellationToken)
        {
            var authenticationResult =
                await _authenticationService.GetTokkenAsync(
                    request.Email,
                    request.Password,
                    cancellationToken);

            return authenticationResult is null
                ? BadRequest("invalid email or password")
                : Ok(authenticationResult);
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register(
            RegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result =
                await _authenticationService.RegisterAsync(
                    request,
                    cancellationToken);

            return result is null ? BadRequest() : Ok(result);
        }

        [HttpPost("refresh")]
        public async Task<IActionResult> Refresh(RefreshRequest request)
        {
            var result =
                await _authenticationService.RefreshTokenAsync(
                    request.RefreshToken);

            return result is null ? BadRequest() : Ok(result);
        }
    }
}