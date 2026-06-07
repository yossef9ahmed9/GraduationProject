namespace GraduationProject.Contracts.Authentication
{
    // PatientId removed — relative registers alone then sends a link request
    public record RelativeRegisterRequest(
        string FullName,
        string Email,
        string Password,
        string ConfirmPassword,
        string Phone,
        string RelationType
    );
}
