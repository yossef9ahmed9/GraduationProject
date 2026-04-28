using GraduationProject.Services.OCR;

namespace GraduationProject.Services
{
    public class FileService : IFileService
    {
        public async Task<byte[]> GetBytesAsync(IFormFile file)
        {
            using var ms = new MemoryStream();
            await file.CopyToAsync(ms);
            return ms.ToArray();
        }
    }
}