namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController(IAuthService authenticationService) : ControllerBase
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

            return authenticationResult.IsSuccess
                ? Ok(authenticationResult.Value)
                : authenticationResult.ToProblem();
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

            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("refresh")]
        public async Task<IActionResult> Refresh(RefreshRequest request)
        {
            var result =
                await _authenticationService.RefreshTokenAsync(
                    request.RefreshToken);

            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // NEW: call this with the user's email to get a reset token
        // in production this token would be sent via email instead of returned here
        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request)
        {
            var result = await _authenticationService.ForgotPasswordAsync(request.Email);

            return result.IsSuccess
                ? Ok(new { message = "Use this token to reset your password.", resetToken = result.Value })
                : result.ToProblem();
        }

        // NEW: call this with the token from forgot-password + new password to reset
        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword(ResetPasswordRequest request)
        {
            var result = await _authenticationService.ResetPasswordAsync(request);

            return result.IsSuccess
                ? Ok(new { message = "Password has been reset successfully." })
                : result.ToProblem();
        }
    }
}