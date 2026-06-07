namespace GraduationProject.Contracts.Authentication
{
    public record DoctorRegisterRequest
    (
        string FullName,
        string Email,
        string Password,
        string ConfirmPassword,
        string Phone,
        string Specialization,
        // Optional clinic info — can be added at registration or later via profile
        string? ClinicName     = null,
        string? ClinicAddress  = null,
        double? ClinicLatitude  = null,
        double? ClinicLongitude = null
    );
}