namespace GraduationProject.Contracts.Authentication
{
    public record LabRegisterRequest
    (
        string Email,
        string Password,
        string ConfirmPassword,
        string LabName,
        string Location,
        string Phone,
        // Optional coordinates — can be added at registration or later via profile
        double? Latitude  = null,
        double? Longitude = null
    );
}