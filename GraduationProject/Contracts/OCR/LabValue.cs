namespace GraduationProject.Contracts.OCR
{
    public class LabValue
    {
        public string Name { get; set; } = string.Empty;
        public double Value { get; set; }
        public double? Min { get; set; }
        public double? Max { get; set; }
        public string Status { get; set; } = "Normal";
    }
}