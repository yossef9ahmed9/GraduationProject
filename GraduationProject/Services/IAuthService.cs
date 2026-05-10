namespace GraduationProject.Services
{
    public interface IAuthService
    {
        Task<Result<AuthResponse?>> GetTokkenAsync(
            string email,
            string password,
            CancellationToken cancellationToken = default);

        // UPDATED: replaced single RegisterAsync with one method per role
        // each method only accepts the fields that role actually needs
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

        Task<Result<string>> ForgotPasswordAsync(string email);

        Task<Result> ResetPasswordAsync(ResetPasswordRequest request);
    }
}