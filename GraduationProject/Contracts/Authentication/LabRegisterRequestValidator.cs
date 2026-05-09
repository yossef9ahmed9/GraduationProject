using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated validator for lab registration
    // replaces the conditional When(role == "Lab") block in the old RegisterRequestValidator
    public class LabRegisterRequestValidator : AbstractValidator<LabRegisterRequest>
    {
        public LabRegisterRequestValidator()
        {
            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Email is required.")
                .EmailAddress().WithMessage("Invalid email format.");

            RuleFor(x => x.Password)
                .NotEmpty().WithMessage("Password is required.")
                .MinimumLength(6).WithMessage("Password must be at least 6 characters.");

            RuleFor(x => x.ConfirmPassword)
                .NotEmpty().WithMessage("Confirm password is required.")
                .Equal(x => x.Password).WithMessage("Passwords do not match.");

            RuleFor(x => x.LabName)
                .NotEmpty().WithMessage("Lab name is required.")
                .MaximumLength(150);

            RuleFor(x => x.Location)
                .NotEmpty().WithMessage("Location is required.")
                .MaximumLength(200);

            RuleFor(x => x.Phone)
                .NotEmpty().WithMessage("Phone is required.")
                .Matches(@"^01[0-5][0-9]{8}$")
                .WithMessage("Invalid Egyptian phone number format.");
        }
    }
}