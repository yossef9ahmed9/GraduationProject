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

        // UPDATED: replaced single /register endpoint with one endpoint per role
        // frontend calls the specific endpoint based on the role the user selected
        // each endpoint only accepts the exact fields needed for that role

        // NEW: POST /api/auth/register/patient
        [HttpPost("register/patient")]
        public async Task<IActionResult> RegisterPatient(
            PatientRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterPatientAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // NEW: POST /api/auth/register/doctor
        [HttpPost("register/doctor")]
        public async Task<IActionResult> RegisterDoctor(
            DoctorRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterDoctorAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // NEW: POST /api/auth/register/lab
        [HttpPost("register/lab")]
        public async Task<IActionResult> RegisterLab(
            LabRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterLabAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // NEW: POST /api/auth/register/relative
        [HttpPost("register/relative")]
        public async Task<IActionResult> RegisterRelative(
            RelativeRegisterRequest request,
            CancellationToken cancellationToken)
        {
            var result = await _authenticationService.RegisterRelativeAsync(request, cancellationToken);
            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        // NEW: POST /api/auth/register/ambulance
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
            var result =
                await _authenticationService.RefreshTokenAsync(
                    request.RefreshToken);

            return result.IsSuccess ? Ok(result.Value) : result.ToProblem();
        }

        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword(ForgotPasswordRequest request)
        {
            var result = await _authenticationService.ForgotPasswordAsync(request.Email);

            return result.IsSuccess
                ? Ok(new { message = "Use this token to reset your password.", resetToken = result.Value })
                : result.ToProblem();
        }

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