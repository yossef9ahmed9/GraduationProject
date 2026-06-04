using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    public class AmbulanceRegisterRequestValidator : AbstractValidator<AmbulanceRegisterRequest>
    {
        public AmbulanceRegisterRequestValidator()
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

            RuleFor(x => x.StationName)
                .NotEmpty().WithMessage("Station name is required.")
                .MaximumLength(100);

            RuleFor(x => x.Phone)
                .NotEmpty().WithMessage("Phone is required.")
                .Matches(@"^01[0-5][0-9]{8}$")
                .WithMessage("Invalid Egyptian phone number format.");

            RuleFor(x => x.AvailabilityStatus)
                .NotEmpty().WithMessage("Availability status is required.")
                .Must(s => s == "Available" || s == "Busy" || s == "OutOfService")
                .WithMessage("Availability status must be Available, Busy, or OutOfService.");

            // FIXED: these were nullable before so validation never ran on them
            RuleFor(x => x.LicensePlate)
                .NotEmpty().WithMessage("License plate is required.")
                .MaximumLength(20);

            RuleFor(x => x.DriverName)
                .NotEmpty().WithMessage("Driver name is required.")
                .MaximumLength(100);

            RuleFor(x => x.DriverPhone)
                .NotEmpty().WithMessage("Driver phone is required.")
                .Matches(@"^01[0-5][0-9]{8}$")
                .WithMessage("Invalid Egyptian driver phone number format.");
        }
    }
}
