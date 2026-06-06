namespace GraduationProject.Contracts.EmergencyDispatches
{
    public class EmergencyDispatchRequestValidator : AbstractValidator<EmergencyDispatchRequest>
    {
        public EmergencyDispatchRequestValidator()
        {
            RuleFor(x => x.PatientId)
                .GreaterThan(0).WithMessage("Valid Patient ID is required.");

            RuleFor(x => x.AmbulanceId)
                .GreaterThan(0).WithMessage("Valid Ambulance ID is required.");

            RuleFor(x => x.PatientLatitude)
                .InclusiveBetween(-90, 90)
                .WithMessage("Latitude must be between -90 and 90.");

            RuleFor(x => x.PatientLongitude)
                .InclusiveBetween(-180, 180)
                .WithMessage("Longitude must be between -180 and 180.");

            RuleFor(x => x.Notes)
                .MaximumLength(500).WithMessage("Notes must not exceed 500 characters.");
        }
    }
}
