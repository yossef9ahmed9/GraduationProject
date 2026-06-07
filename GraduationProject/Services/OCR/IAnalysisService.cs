using GraduationProject.Contracts.OCR;

namespace GraduationProject.Services.OCR
{
    public interface IAnalysisService
    {
        AnalysisResult Analyze(string text);
        AnalysisResult Analyze(string text, string? testType);
        string DetectTestType(string text);
    }
}