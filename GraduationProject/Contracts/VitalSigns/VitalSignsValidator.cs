using FluentValidation;

namespace GraduationProject.Contracts.VitalSigns
{
    public class VitalSignsValidator : AbstractValidator<VitalSignsRequest>
    {
        public VitalSignsValidator()
        {
            RuleFor(x => x.HeartRate)
                .GreaterThan(0).WithMessage("Heart rate must be greater than 0.")
                .LessThan(300).WithMessage("Heart rate value is unrealistic.");

            RuleFor(x => x.OxygenSaturation)
                .InclusiveBetween(0, 100)
                .WithMessage("Oxygen saturation must be between 0 and 100.");

            RuleFor(x => x.SensorId)
                .GreaterThan(0).WithMessage("Valid Sensor ID is required.");

            RuleFor(x => x.PatientId)
                .GreaterThan(0).WithMessage("Valid Patient ID is required.");
        }
    }
}
