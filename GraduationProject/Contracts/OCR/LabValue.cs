namespace GraduationProject.Contracts.OCR
{
    public class LabValue
    {
        public string Name { get; set; } = string.Empty;
        public double Value { get; set; }
        public double? Min { get; set; }
        public double? Max { get; set; }
        public string Status { get; set; } = "Normal";
        // For text-only fields (e.g. urine Color, Clarity, Protein +/-)
        public string? TextValue { get; set; }
    }
}