namespace GraduationProject.Contracts.OCR
{
    public class AnalysisResult
    {
        public string Status { get; set; } = string.Empty;

        public List<LabValue> Tests { get; set; } = new();

        public List<string> Alerts { get; set; } = new();
    }
}