using FluentValidation;
using GraduationProject.Contracts.Relatives;

namespace GraduationProject.Contracts.Relatives
{
    public class RelativeValidator : AbstractValidator<RelativeRequest>
    {
        public RelativeValidator()
        {
            RuleFor(x => x.Name).NotEmpty();
            RuleFor(x => x.PatientId).GreaterThan(0);
        }
    }
}