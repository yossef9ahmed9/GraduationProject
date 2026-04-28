using FluentValidation;

namespace GraduationProject.Contracts.VitalSigns
{
    public class VitalSignsValidator : AbstractValidator<VitalSignsRequest>
    {
        public VitalSignsValidator()
        {
            RuleFor(x => x.HeartRate).GreaterThan(0);
            RuleFor(x => x.SensorId).GreaterThan(0);
        }
    }
}