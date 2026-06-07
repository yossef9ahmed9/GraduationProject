namespace GraduationProject.Contracts.Authentication;

public record ChangePasswordRequest(string CurrentPassword, string NewPassword);
