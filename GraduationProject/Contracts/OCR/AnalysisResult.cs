namespace GraduationProject.Contracts.OCR
{
    public class AnalysisResult
    {
        public string Status { get; set; } = string.Empty;

        public List<LabValue> Tests { get; set; } = new();

        public List<string> Alerts { get; set; } = new();

<<<<<<< HEAD
        // NEW: false when OCR couldn't extract any real values (all zeros)
        // used by OcrController to reject saving and return a helpful error
=======
>>>>>>> c61d184 (Add pagination, OCR image storage, and merge OCR all-zeros fix)
        public bool IsValidScan { get; set; } = true;
    }
}
