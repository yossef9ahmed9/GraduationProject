using FluentValidation;

namespace GraduationProject.Contracts.VitalSigns
{
    /// <summary>
    /// Minimal request sent by the ESP32/Arduino sensor.
    /// No SensorId required — the backend resolves it automatically.
    /// </summary>
    public record SensorVitalRequest(
        int    PatientId,
        int    HeartRate,
        double OxygenSaturation
    );

    public class SensorVitalRequestValidator : AbstractValidator<SensorVitalRequest>
    {
        public SensorVitalRequestValidator()
        {
            RuleFor(x => x.PatientId)
                .GreaterThan(0).WithMessage("Valid Patient ID is required.");

            RuleFor(x => x.HeartRate)
                .GreaterThan(0).WithMessage("Heart rate must be greater than 0.")
                .LessThan(300).WithMessage("Heart rate value is unrealistic.");

            RuleFor(x => x.OxygenSaturation)
                .InclusiveBetween(0, 100)
                .WithMessage("Oxygen saturation must be between 0 and 100.");
        }
    }
}
