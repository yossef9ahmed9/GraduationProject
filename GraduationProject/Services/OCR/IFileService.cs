namespace GraduationProject.Services.OCR

{
    public interface IFileService
    {
        Task<byte[]> GetBytesAsync(IFormFile file);
    }
}
