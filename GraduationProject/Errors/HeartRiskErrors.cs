// ============================================================
// File: GraduationProject/Errors/HeartRiskErrors.cs
// ============================================================
namespace GraduationProject.Errors
{
    public static class HeartRiskErrors
    {
        public static readonly Error ServiceUnavailable =
            new("HeartRisk.ServiceUnavailable",
                "The AI risk model service is currently unavailable. Please try again later.",
                StatusCodes.Status503ServiceUnavailable);

        public static readonly Error InvalidResponse =
            new("HeartRisk.InvalidResponse",
                "The AI model returned an unexpected response.",
                StatusCodes.Status502BadGateway);

        public static readonly Error InternalError =
            new("HeartRisk.InternalError",
                "An unexpected error occurred while calling the AI model.",
                StatusCodes.Status500InternalServerError);
    }
}
