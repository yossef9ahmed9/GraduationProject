using GraduationProject.Services.OCR;
using Microsoft.AspNetCore.Hosting;

namespace GraduationProject.Services
{
    public class FileService(IWebHostEnvironment env) : IFileService
    {
        public async Task<byte[]> GetBytesAsync(IFormFile file)
        {
            using var ms = new MemoryStream();
            await file.CopyToAsync(ms);
            return ms.ToArray();
        }

        public async Task<string> SaveFileAsync(
            byte[] bytes, string subfolder, string fileName)
        {
            var uploadsDir = Path.Combine(env.WebRootPath, subfolder);

            Directory.CreateDirectory(uploadsDir);

            var filePath = Path.Combine(uploadsDir, fileName);
            await File.WriteAllBytesAsync(filePath, bytes);

            return Path.Combine(subfolder, fileName).Replace("\\", "/");
        }
    }
}