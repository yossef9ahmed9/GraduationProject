namespace GraduationProject.Services.OCR

{
    public interface IFileService
    {
        Task<byte[]> GetBytesAsync(IFormFile file);
        Task<string> SaveFileAsync(byte[] bytes, string subfolder, string fileName);
    }
}
