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

        [HttpPost("register/patient")]
        public async Task<IActionResult> RegisterPatient(
            PatientRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterPatientAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("register/doctor")]
        public async Task<IActionResult> RegisterDoctor(
            DoctorRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterDoctorAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("register/lab")]
        public async Task<IActionResult> RegisterLab(
            LabRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterLabAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("register/relative")]
        public async Task<IActionResult> RegisterRelative(
            RelativeRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterRelativeAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("register/ambulance")]
        public async Task<IActionResult> RegisterAmbulance(
            AmbulanceRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterAmbulanceAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("refresh")]
        public async Task<IActionResult> Refresh(RefreshRequest request)
        {
            var result = await _authenticationService.RefreshTokenAsync(request.RefreshToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request)
        {
            // FIXED: ForgotPasswordAsync now returns Result (no token in the body).
            // The reset token is emailed to the user.
            // We always return the same 200 message regardless of whether the email
            // exists — this prevents user enumeration attacks.
            await _authenticationService.ForgotPasswordAsync(request.Email);
            return Ok(new { message = "If that email is registered, a password reset link has been sent." });
        }

        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword(ResetPasswordRequest request)
        {
            var result = await _authenticationService.ResetPasswordAsync(request);

            return result.IsSuccess
                ? Ok(new { message = "Password has been reset successfully." })
                : result.ToProblem();
        }

        // PUT /api/auth/change-password  (requires auth)
        [HttpPut("change-password")]
        [Authorize]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
        {
            var email = User.FindFirst("email")?.Value
                     ?? User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? "";

            var result = await _authenticationService.ChangePasswordAsync(email, request.CurrentPassword, request.NewPassword);
            return result.IsSuccess
                ? Ok(new { message = "Password changed successfully." })
                : result.ToProblem();
        }

        // PUT /api/auth/update-name  (requires auth)
        [HttpPut("update-name")]
        [Authorize]
        public async Task<IActionResult> UpdateName([FromBody] UpdateNameRequest request)
        {
            var email = User.FindFirst("email")?.Value
                     ?? User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? "";

            var result = await _authenticationService.UpdateNameAsync(email, request.NewName);
            return result.IsSuccess
                ? Ok(new { message = "Name updated successfully." })
                : result.ToProblem();
        }

        // PUT /api/auth/profile-picture  (requires auth)
        [HttpPut("profile-picture")]
        [Authorize]
        [RequestSizeLimit(10 * 1024 * 1024)] // 10 MB
        public async Task<IActionResult> UploadProfilePicture([FromForm] ProfilePictureUploadRequest request)
        {
            var email = User.FindFirst("email")?.Value
                     ?? User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? "";

            var webRootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
            var result = await _authenticationService.UploadProfilePictureAsync(email, request.File, webRootPath);
            return result.IsSuccess
                ? Ok(new { url = result.Value })
                : result.ToProblem();
        }

        // GET /api/auth/me  (requires auth)
        [HttpGet("me")]
        [Authorize]
        public async Task<IActionResult> Me()
        {
            var email = User.FindFirst("email")?.Value
                     ?? User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value ?? "";
            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "";

            var userManager = HttpContext.RequestServices.GetRequiredService<UserManager<ApplicationUser>>();
            var user = await userManager.FindByEmailAsync(email);
            if (user is null) return Unauthorized();

            return Ok(new
            {
                id               = user.Id,
                fullName         = user.FullName,
                email            = user.Email,
                profilePictureUrl = user.ProfilePictureUrl
            });
        }
    }
}
