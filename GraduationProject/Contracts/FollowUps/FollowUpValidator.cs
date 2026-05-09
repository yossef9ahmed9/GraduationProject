using FluentValidation;
using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Contracts.FollowUps
{
    public class FollowUpValidator : AbstractValidator<FollowUpRequest>
    {
        private static readonly string[] ValidSeverities =
            { "Low", "Medium", "High", "Critical" };

        public FollowUpValidator()
        {
            RuleFor(x => x.Diagnosis).NotEmpty().MaximumLength(500);
            RuleFor(x => x.TreatmentPlan).NotEmpty().MaximumLength(1000);
            RuleFor(x => x.PatientId).GreaterThan(0);
            RuleFor(x => x.DoctorId).GreaterThan(0);

            RuleFor(x => x.Severity)
                .Must(s => ValidSeverities.Contains(s, StringComparer.OrdinalIgnoreCase))
                .WithMessage($"Severity must be one of: {string.Join(", ", ValidSeverities)}");

            RuleFor(x => x.NextVisitDate)
                .GreaterThan(DateTime.UtcNow)
                .When(x => x.NextVisitDate.HasValue)
                .WithMessage("Next visit date must be in the future.");
        }
    }
}