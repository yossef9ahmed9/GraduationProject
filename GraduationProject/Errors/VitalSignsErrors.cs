namespace GraduationProject.Errors
{
    public static class VitalSignsErrors
    {
        public static readonly Error VitalSignsNotFound =
            new("VitalSigns.NotFound", "No vital signs found for this patient",
                StatusCodes.Status404NotFound);

        // NEW: patient must exist before saving vitals
        public static readonly Error PatientNotFound =
            new("VitalSigns.PatientNotFound", "No patient found with the given ID",
                StatusCodes.Status404NotFound);

        // NEW: sensor must belong to the patient being monitored
        public static readonly Error SensorNotBelongToPatient =
            new("VitalSigns.SensorMismatch",
                "This sensor does not belong to the given patient",
                StatusCodes.Status400BadRequest);
    }
}