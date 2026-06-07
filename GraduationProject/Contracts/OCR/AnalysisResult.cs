namespace GraduationProject.Contracts.OCR
{
    public class AnalysisResult
    {
        public string Status { get; set; } = string.Empty;

        public List<LabValue> Tests { get; set; } = new();

        public List<string> Alerts { get; set; } = new();

        // false when OCR couldn't extract any real values (all zeros or nothing found)
        // used by OcrController to reject saving and return a helpful error to the caller
        public bool IsValidScan { get; set; } = true;

        // The detected (or provided) test type — e.g. "CBC", "Lipid Panel", "Kidney Function"
        public string TestType { get; set; } = "CBC";
    }
}
