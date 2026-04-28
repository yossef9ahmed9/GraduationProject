
namespace GraduationProject.Contracts.Authentication
{
    public record RegisterRequest
    (
        string FullName,
        string Email,
        string Password
    );
}