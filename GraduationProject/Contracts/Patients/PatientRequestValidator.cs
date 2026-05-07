using FluentValidation;

namespace GraduationProject.Contracts.Patients
{
    
    
        public class PatientRequestValidator : AbstractValidator<PatientRequest>
        {
            public PatientRequestValidator()
            {
            RuleFor(p => p.Name)
                .NotEmpty().WithMessage("Name is required.")
                .MaximumLength(100);
                  

                RuleFor(p => p.Gender)
                    .NotEmpty().WithMessage("Gender is required.")
                    .Must(g =>
                        
                        (g.Equals("Male", StringComparison.OrdinalIgnoreCase) ||
                         g.Equals("Female", StringComparison.OrdinalIgnoreCase)))
                    .WithMessage("Gender must be Male or Female.");

                RuleFor(p => p.Phone)
                    .NotEmpty().WithMessage("Phone number is required.")
                    .Matches(@"^01[0-5][0-9]{8}$")
                    .WithMessage("Invalid Egyptian phone number format.");

                RuleFor(p => p.Email)
                    .NotEmpty().WithMessage("Email is required.")
                    .EmailAddress().WithMessage("Invalid email format.")
                    .MaximumLength(150);

                RuleFor(p => p.Address)
                    .NotEmpty().WithMessage("Address is required.")
                    .MaximumLength(250);

                RuleFor(p => p.MedicalRecord)
                    .NotEmpty().WithMessage("Medical record is required.")
                    .MaximumLength(1000);

                RuleFor(p => p.BirthDate)
                    .NotEmpty().WithMessage("Birth date is required.")
                    .Must(BeAValidBirthDate)
                    .WithMessage("Birth date must be in the past and within the last 120 years.");
            }

            private bool BeAValidBirthDate(DateOnly birthDate)
            {
                var today = DateOnly.FromDateTime(DateTime.Today);
                var minDate = today.AddYears(-120);

                return birthDate < today && birthDate > minDate;
            }
        }
    }
