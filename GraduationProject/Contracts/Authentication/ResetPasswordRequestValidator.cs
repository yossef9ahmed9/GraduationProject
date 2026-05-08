using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    // NEW FILE: validates the reset password request
    public class ResetPasswordRequestValidator : AbstractValidator<ResetPasswordRequest>
    {
        public ResetPasswordRequestValidator()
        {
            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Email is required.")
                .EmailAddress().WithMessage("Invalid email format.");

            RuleFor(x => x.Token)
                .NotEmpty().WithMessage("Reset token is required.");

            RuleFor(x => x.NewPassword)
                .NotEmpty().WithMessage("New password is required.")
                .MinimumLength(6).WithMessage("Password must be at least 6 characters.");

            // NEW: confirm new password must match new password
            RuleFor(x => x.ConfirmNewPassword)
                .NotEmpty().WithMessage("Confirm New Password is required.")
                .Equal(x => x.NewPassword).WithMessage("Passwords do not match.");
        }
    }
}