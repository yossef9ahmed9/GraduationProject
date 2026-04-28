using FluentValidation;

namespace GraduationProject.Contracts.Doctors
{
    public class DoctorValidator : AbstractValidator<DoctorRequest>
    {
        public DoctorValidator()
        {
            RuleFor(x => x.Name).NotEmpty().MaximumLength(100);
            RuleFor(x => x.Phone).NotEmpty();
            RuleFor(x => x.Email).EmailAddress();
        }
    }
}