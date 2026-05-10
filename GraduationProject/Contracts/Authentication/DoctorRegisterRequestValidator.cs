using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated validator for doctor registration
    // replaces the conditional When(role == "Doctor") block in the old RegisterRequestValidator
    public class DoctorRegisterRequestValidator : AbstractValidator<DoctorRegisterRequest>
    {
        public DoctorRegisterRequestValidator()
        {
            RuleFor(x => x.FullName)
                .NotEmpty().WithMessage("Full name is required.")
                .MaximumLength(100);

            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Email is required.")
                .EmailAddress().WithMessage("Invalid email format.");

            RuleFor(x => x.Password)
                .NotEmpty().WithMessage("Password is required.")
                .MinimumLength(6).WithMessage("Password must be at least 6 characters.");

            RuleFor(x => x.ConfirmPassword)
                .NotEmpty().WithMessage("Confirm password is required.")
                .Equal(x => x.Password).WithMessage("Passwords do not match.");

            RuleFor(x => x.Phone)
                .NotEmpty().WithMessage("Phone is required.")
                .Matches(@"^01[0-5][0-9]{8}$")
                .WithMessage("Invalid Egyptian phone number format.");

            RuleFor(x => x.Specialization)
                .NotEmpty().WithMessage("Specialization is required.")
                .MaximumLength(100);
        }
    }
}