namespace GraduationProject.Services
{
    public interface IAuthService
    {
        Task<Result<AuthResponse?>> GetTokkenAsync(
            string email,
            string password,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RegisterPatientAsync(
            PatientRegisterRequest request,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RegisterDoctorAsync(
            DoctorRegisterRequest request,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RegisterLabAsync(
            LabRegisterRequest request,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RegisterRelativeAsync(
            RelativeRegisterRequest request,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RegisterAmbulanceAsync(
            AmbulanceRegisterRequest request,
            CancellationToken cancellationToken = default);

        Task<Result<AuthResponse?>> RefreshTokenAsync(string token);

        // FIXED: returns Result (not Result<string>) — the token is sent via email,
        // never returned in the HTTP response.
        Task<Result> ForgotPasswordAsync(string email);

        Task<Result> ResetPasswordAsync(ResetPasswordRequest request);
    }
}
