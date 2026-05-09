using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    // NEW: dedicated validator for patient registration
    // replaces the conditional When(role == "Patient") block in the old RegisterRequestValidator
    public class PatientRegisterRequestValidator : AbstractValidator<PatientRegisterRequest>
    {
        public PatientRegisterRequestValidator()
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

            RuleFor(x => x.Gender)
                .NotEmpty().WithMessage("Gender is required.")
                .Must(g => g.Equals("Male", StringComparison.OrdinalIgnoreCase) ||
                           g.Equals("Female", StringComparison.OrdinalIgnoreCase))
                .WithMessage("Gender must be Male or Female.");

            RuleFor(x => x.Phone)
                .NotEmpty().WithMessage("Phone is required.")
                .Matches(@"^01[0-5][0-9]{8}$")
                .WithMessage("Invalid Egyptian phone number format.");

            RuleFor(x => x.Address)
                .NotEmpty().WithMessage("Address is required.")
                .MaximumLength(250);

            RuleFor(x => x.BirthDate)
                .NotEmpty().WithMessage("Birth date is required.")
                .Must(b => b < DateOnly.FromDateTime(DateTime.Today))
                .WithMessage("Birth date must be in the past.");

            RuleFor(x => x.MedicalRecord)
                .NotEmpty().WithMessage("Medical record is required.")
                .MaximumLength(1000);
        }
    }
}