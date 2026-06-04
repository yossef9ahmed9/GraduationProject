// ============================================================
// File: GraduationProject/Contracts/HeartRisk/HeartRiskRequestValidator.cs
// ============================================================
using FluentValidation;
using GraduationProject.Contracts.HeartRisk;

namespace GraduationProject.Contracts.HeartRisk
{
    public class HeartRiskRequestValidator : AbstractValidator<HeartRiskRequest>
    {
        public HeartRiskRequestValidator()
        {
            RuleFor(x => x.Bpm)
                .InclusiveBetween(20, 300)
                .WithMessage("BPM must be between 20 and 300.");

            RuleFor(x => x.Spo2)
                .InclusiveBetween(50, 100)
                .WithMessage("SpO2 must be between 50% and 100%.");

            RuleFor(x => x.HrvMs)
                .InclusiveBetween(1, 200)
                .WithMessage("HRV must be between 1 ms and 200 ms.");

            RuleFor(x => x.Age)
                .InclusiveBetween(1, 120)
                .WithMessage("Age must be between 1 and 120.");

            RuleFor(x => x.Sex)
                .InclusiveBetween(0, 1)
                .WithMessage("Sex must be 0 (female) or 1 (male).");
        }
    }

    public class HeartRiskWindowRequestValidator : AbstractValidator<HeartRiskWindowRequest>
    {
        public HeartRiskWindowRequestValidator()
        {
            RuleFor(x => x.BpmAvg) .GreaterThan(0).WithMessage("BPM average must be positive.");
            RuleFor(x => x.BpmMin) .GreaterThan(0).WithMessage("BPM minimum must be positive.");
            RuleFor(x => x.BpmMax) .GreaterThan(0).WithMessage("BPM maximum must be positive.");
            RuleFor(x => x.Spo2Avg).InclusiveBetween(50, 100).WithMessage("SpO2 average must be 50–100.");
            RuleFor(x => x.Spo2Min).InclusiveBetween(50, 100).WithMessage("SpO2 minimum must be 50–100.");
            RuleFor(x => x.HrvMs)  .InclusiveBetween(1, 200) .WithMessage("HRV must be 1–200 ms.");
            RuleFor(x => x.Age)    .InclusiveBetween(1, 120) .WithMessage("Age must be 1–120.");
            RuleFor(x => x.Sex)    .InclusiveBetween(0, 1)   .WithMessage("Sex must be 0 or 1.");
        }
    }

    public class HeartRiskBatchRequestValidator : AbstractValidator<HeartRiskBatchRequest>
    {
        public HeartRiskBatchRequestValidator()
        {
            RuleFor(x => x.Readings)
                .NotEmpty().WithMessage("At least one reading is required.")
                .Must(r => r.Count <= 200).WithMessage("Maximum 200 readings per batch.");

            RuleForEach(x => x.Readings).SetValidator(new HeartRiskRequestValidator());
        }
    }
}
