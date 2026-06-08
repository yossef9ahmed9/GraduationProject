using FluentValidation;

namespace GraduationProject.Contracts.Authentication
{
    public class AmbulanceRegisterRequestValidator : AbstractValidator<AmbulanceRegisterRequest>
    {
        public AmbulanceRegisterRequestValidator()
        {
            RuleFor(x => x.Email).NotEmpty().EmailAddress();
            RuleFor(x => x.Password).NotEmpty().MinimumLength(6);
            RuleFor(x => x.ConfirmPassword).NotEmpty()
                .Equal(x => x.Password).WithMessage("Passwords do not match.");
            RuleFor(x => x.Phone).NotEmpty()
                .Matches(@"^01[0-5][0-9]{8}$").WithMessage("Invalid Egyptian phone number.");
            RuleFor(x => x.DriverName).NotEmpty().MaximumLength(100);
            RuleFor(x => x.DriverPhone).NotEmpty()
                .Matches(@"^01[0-5][0-9]{8}$").WithMessage("Invalid driver phone number.");
            RuleFor(x => x.LicensePlate).NotEmpty().MaximumLength(20);
            RuleFor(x => x.ServiceArea).MaximumLength(100)
                .When(x => x.ServiceArea != null);
        }
    }
}
