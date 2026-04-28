using GraduationProject.Contracts.OCR;

namespace GraduationProject.Services.OCR
{
    public interface IAnalysisService
    {
        AnalysisResult Analyze(string text);
    }
}