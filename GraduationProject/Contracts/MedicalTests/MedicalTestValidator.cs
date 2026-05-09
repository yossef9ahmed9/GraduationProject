namespace GraduationProject.Contracts.MedicalTests
{
    public class MedicalTestValidator : AbstractValidator<MedicalTestRequest>
    {
        public MedicalTestValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Test name is required.")
                .MaximumLength(100).WithMessage("Test name cannot exceed 100 characters.");

            RuleFor(x => x.Result)
                .NotEmpty().WithMessage("Test result is required.")
                .MaximumLength(200).WithMessage("Result cannot exceed 200 characters.");

            RuleFor(x => x.PatientId)
                .GreaterThan(0).WithMessage("A valid PatientId is required.");

            RuleFor(x => x.LabId)
                .GreaterThan(0).WithMessage("A valid LabId is required.");
        }
    }
}
