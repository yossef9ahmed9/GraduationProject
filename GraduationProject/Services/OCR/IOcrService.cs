namespace GraduationProject.Services.OCR
{
    public interface IOcrService
    {
        string ExtractText(byte[] imageBytes);

    }
}