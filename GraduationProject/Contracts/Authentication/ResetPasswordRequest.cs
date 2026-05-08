namespace GraduationProject.Contracts.Authentication
{
    // NEW FILE: request model for resetting the password
    public record ResetPasswordRequest
    (
        string Email,
        string Token,           // the token received from forgot password
        string NewPassword,
        string ConfirmNewPassword
    );
}