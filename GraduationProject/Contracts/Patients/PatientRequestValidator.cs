using FluentValidation;

namespace GraduationProject.Contracts.Patients
{
    public class LoginRequestValidator : AbstractValidator<PatientRequest>
    {
        public LoginRequestValidator()
        {
            RuleFor(p => p.Name)
                .NotEmpty().WithMessage("Name is required.")
                .MaximumLength(100).WithMessage("Name cannot exceed 100 characters.");




            RuleFor(p => p.Gender)
                    .NotEmpty().WithMessage("You must enter your gender")
                    // .Must(g => g == "male" || g == "female");

                    .Must(g =>
                         g.Equals("Male", StringComparison.OrdinalIgnoreCase) ||
                         g.Equals("Female", StringComparison.OrdinalIgnoreCase))
                             .WithMessage("Gender must be Male or Female");


            RuleFor(p => p.Phone)
                    .NotEmpty().WithMessage("Phone number is required.")
                    .Matches(@"^01[0-5][0-9]{8}$")
                         .WithMessage("Invalid Egyptian phone number format.");

            RuleFor(p => p.Email)
                    .NotEmpty().WithMessage("Email is required.")
                    .EmailAddress().WithMessage("Invalid email format.");

            RuleFor(p => p.Address)
                    .NotEmpty().WithMessage("Address is required.");

            RuleFor(p => p.MedicalRecord)
                    .NotEmpty().WithMessage("Medical record is required.");

            RuleFor(p => p.BirthDate)
                    .Must(ValidBirthDate)
                         .WithMessage("Birth date must be in the past and within the last 120 years.");
        }

        private bool ValidBirthDate(DateOnly birthDate)
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            var minDate = today.AddYears(-120);
            return birthDate < today && birthDate > minDate;
        }
    }

}