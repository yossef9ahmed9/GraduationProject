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

            RuleFor(x => x.SensorId)
                .GreaterThan(0).WithMessage("Valid Sensor ID is required.");

            // NEW: patient id is now required
            RuleFor(x => x.PatientId)
                .GreaterThan(0).WithMessage("Valid Patient ID is required.");

            // NEW: optional but validated if provided
            When(x => x.OxygenSaturation.HasValue, () =>
            {
                RuleFor(x => x.OxygenSaturation)
                    .InclusiveBetween(0, 100)
                    .WithMessage("Oxygen saturation must be between 0 and 100.");
            });

            When(x => x.Temperature.HasValue, () =>
            {
                RuleFor(x => x.Temperature)
                    .InclusiveBetween(30, 45)
                    .WithMessage("Temperature must be between 30 and 45 Celsius.");
            });

            When(x => x.BloodPressureSystolic.HasValue, () =>
            {
                RuleFor(x => x.BloodPressureSystolic)
                    .GreaterThan(0).WithMessage("Blood pressure systolic must be greater than 0.");
            });

            When(x => x.BloodPressureDiastolic.HasValue, () =>
            {
                RuleFor(x => x.BloodPressureDiastolic)
                    .GreaterThan(0).WithMessage("Blood pressure diastolic must be greater than 0.");
            });
        }
    }
}