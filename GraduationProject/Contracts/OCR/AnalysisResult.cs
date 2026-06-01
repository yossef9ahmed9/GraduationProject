namespace GraduationProject.Contracts.OCR
{
    public class AnalysisResult
    {
        public string Status { get; set; } = string.Empty;

        public List<LabValue> Tests { get; set; } = new();

        public List<string> Alerts { get; set; } = new();

        // NEW: false when OCR couldn't extract any real values (all zeros)
        // used by OcrController to reject saving and return a helpful error
        public bool IsValidScan { get; set; } = true;
    }
}
