using FluentValidation;
using GraduationProject.Contracts.Sensors;

namespace GraduationProject.Contracts.Sensors
{
    public class SensorValidator : AbstractValidator<SensorRequest>
    {
        public SensorValidator()
        {
            RuleFor(x => x.Type).NotEmpty();
            RuleFor(x => x.PatientId).GreaterThan(0);
        }
    }
}