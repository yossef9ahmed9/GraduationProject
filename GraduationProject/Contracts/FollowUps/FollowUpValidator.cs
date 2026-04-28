using FluentValidation;
using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Contracts.FollowUps
{
    public class FollowUpValidator : AbstractValidator<FollowUpRequest>
    {
        public FollowUpValidator()
        {
            RuleFor(x => x.PatientId).GreaterThan(0);
            RuleFor(x => x.DoctorId).GreaterThan(0);
        }
    }
}