using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    public class PatientRegisterRequestValidator : AbstractValidator<PatientRegisterRequest>
    {
        public PatientRegisterRequestValidator()
        {
            RuleFor(x => x.FullName).NotEmpty().MaximumLength(100);
            RuleFor(x => x.Email).NotEmpty().EmailAddress();
            RuleFor(x => x.Password).NotEmpty().MinimumLength(6);
            RuleFor(x => x.ConfirmPassword).NotEmpty()
                .Equal(x => x.Password).WithMessage("Passwords do not match.");
            RuleFor(x => x.Phone).NotEmpty()
                .Matches(@"^01[0-5][0-9]{8}$").WithMessage("Invalid Egyptian phone number format.");
            RuleFor(x => x.Address).NotEmpty().MaximumLength(250);
            RuleFor(x => x.Gender).NotEmpty()
                .Must(g => g.Equals("Male",   StringComparison.OrdinalIgnoreCase) ||
                           g.Equals("Female", StringComparison.OrdinalIgnoreCase))
                .WithMessage("Gender must be Male or Female.");
            RuleFor(x => x.BirthDate).NotEmpty()
                .Must(b => b < DateOnly.FromDateTime(DateTime.Today))
                .WithMessage("Birth date must be in the past.");
            RuleFor(x => x.BloodType).NotEmpty()
                .Must(b => b is "A+" or "A-" or "B+" or "B-" or "AB+" or "AB-" or "O+" or "O-" or "Unknown")
                .WithMessage("Invalid blood type.");
            // MedicalRecord is optional
            RuleFor(x => x.MedicalRecord).MaximumLength(1000)
                .When(x => x.MedicalRecord != null);
        }
    }
}
