using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    public class RegisterRequestValidator : AbstractValidator<RegisterRequest>
    {
        private static readonly string[] ValidRoles =
            { "Patient", "Doctor", "Lab", "Relative", "Ambulance" };

        public RegisterRequestValidator()
        {
            // shared rules
            RuleFor(x => x.FullName).NotEmpty().MaximumLength(100);
            RuleFor(x => x.Email).NotEmpty().EmailAddress();
            RuleFor(x => x.Password).NotEmpty().MinimumLength(6);
            RuleFor(x => x.ConfirmPassword)
                .NotEmpty().WithMessage("Confirm Password is required.")
                .Equal(x => x.Password).WithMessage("Passwords do not match.");
            RuleFor(x => x.Role)
                .NotEmpty()
                .Must(r => ValidRoles.Contains(r, StringComparer.OrdinalIgnoreCase))
                .WithMessage($"Role must be one of: {string.Join(", ", ValidRoles)}");

            // NEW: Patient rules — only applied when Role is Patient
            When(x => x.Role.Equals("Patient", StringComparison.OrdinalIgnoreCase), () =>
            {
                RuleFor(x => x.Gender)
                    .NotEmpty().WithMessage("Gender is required for Patient.")
                    .Must(g => g!.Equals("Male", StringComparison.OrdinalIgnoreCase) ||
                               g!.Equals("Female", StringComparison.OrdinalIgnoreCase))
                    .WithMessage("Gender must be Male or Female.");

                RuleFor(x => x.Phone)
                    .NotEmpty().WithMessage("Phone is required for Patient.")
                    .Matches(@"^01[0-5][0-9]{8}$")
                    .WithMessage("Invalid Egyptian phone number format.");

                RuleFor(x => x.Address)
                    .NotEmpty().WithMessage("Address is required for Patient.");

                RuleFor(x => x.BirthDate)
                    .NotNull().WithMessage("Birth date is required for Patient.")
                    .Must(b => b < DateOnly.FromDateTime(DateTime.Today))
                    .WithMessage("Birth date must be in the past.");

                RuleFor(x => x.MedicalRecord)
                    .NotEmpty().WithMessage("Medical record is required for Patient.");
            });

            // NEW: Doctor rules — only applied when Role is Doctor
            When(x => x.Role.Equals("Doctor", StringComparison.OrdinalIgnoreCase), () =>
            {
                RuleFor(x => x.Phone)
                    .NotEmpty().WithMessage("Phone is required for Doctor.")
                    .Matches(@"^01[0-5][0-9]{8}$")
                    .WithMessage("Invalid Egyptian phone number format.");

                RuleFor(x => x.Specialization)
                    .NotEmpty().WithMessage("Specialization is required for Doctor.")
                    .MaximumLength(100);
            });

            // NEW: Lab rules — only applied when Role is Lab
            When(x => x.Role.Equals("Lab", StringComparison.OrdinalIgnoreCase), () =>
            {
                RuleFor(x => x.LabName)
                    .NotEmpty().WithMessage("Lab name is required for Lab.")
                    .MaximumLength(150);

                RuleFor(x => x.Location)
                    .NotEmpty().WithMessage("Location is required for Lab.")
                    .MaximumLength(200);

                RuleFor(x => x.Phone)
                    .NotEmpty().WithMessage("Phone is required for Lab.")
                    .Matches(@"^01[0-5][0-9]{8}$")
                    .WithMessage("Invalid Egyptian phone number format.");
            });

            // NEW: Relative rules — only applied when Role is Relative
            When(x => x.Role.Equals("Relative", StringComparison.OrdinalIgnoreCase), () =>
            {
                RuleFor(x => x.Phone)
                    .NotEmpty().WithMessage("Phone is required for Relative.")
                    .Matches(@"^01[0-5][0-9]{8}$")
                    .WithMessage("Invalid Egyptian phone number format.");

                RuleFor(x => x.RelationType)
                    .NotEmpty().WithMessage("Relation type is required for Relative.")
                    .MaximumLength(50);

                RuleFor(x => x.PatientId)
                    .NotNull().WithMessage("Patient ID is required for Relative.")
                    .GreaterThan(0).WithMessage("Patient ID must be a valid ID.");
            });

            // NEW: Ambulance rules — only applied when Role is Ambulance
            When(x => x.Role.Equals("Ambulance", StringComparison.OrdinalIgnoreCase), () =>
            {
                RuleFor(x => x.StationName)
                    .NotEmpty().WithMessage("Station name is required for Ambulance.")
                    .MaximumLength(100);

                RuleFor(x => x.Phone)
                    .NotEmpty().WithMessage("Phone is required for Ambulance.")
                    .Matches(@"^01[0-5][0-9]{8}$")
                    .WithMessage("Invalid Egyptian phone number format.");

                RuleFor(x => x.AvailabilityStatus)
                    .NotEmpty().WithMessage("Availability status is required for Ambulance.")
                    .MaximumLength(50);
            });
        }
    }
}