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

        Task<Result> ForgotPasswordAsync(string email);

        Task<Result> ResetPasswordAsync(ResetPasswordRequest request);

        Task<Result> ChangePasswordAsync(string email, string currentPassword, string newPassword);

        Task<Result> UpdateNameAsync(string email, string newName);

        Task<Result<string>> UploadProfilePictureAsync(string email, IFormFile file, string webRootPath);
    }
}