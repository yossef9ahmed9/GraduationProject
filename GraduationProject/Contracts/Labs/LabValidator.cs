namespace GraduationProject.Contracts.Labs
{
    public class LabValidator : AbstractValidator<LabRequest>
    {
        public LabValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Lab name is required.")
                .MaximumLength(150).WithMessage("Lab name cannot exceed 150 characters.");

            RuleFor(x => x.Location)
                .MaximumLength(200).WithMessage("Location cannot exceed 200 characters.");

            RuleFor(x => x.Phone)
                .Matches(@"^01[0125][0-9]{8}$")
                .WithMessage("Invalid Egyptian phone number.")
                .When(x => !string.IsNullOrEmpty(x.Phone));
        }
    }
}
