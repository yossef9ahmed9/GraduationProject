using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Processing;
using static System.Net.Mime.MediaTypeNames;
using Image = SixLabors.ImageSharp.Image;

namespace GraduationProject.Services.OCR
{
    public static class ImagePreprocessor
    {
        public static byte[] Enhance(byte[] input)
        {
            using var image = Image.Load(input);

            image.Mutate(x =>
            {
                // تكبير الصورة (يحسن OCR جدًا)
                x.Resize(image.Width * 2, image.Height * 2);

                // تحويل grayscale
                x.Grayscale();

                // تحسين التباين
                x.Contrast(1.8f);

                // sharpening قوي للتقارير
                x.GaussianSharpen(1.2f);
            });

            using var ms = new MemoryStream();
            image.Save(ms, new PngEncoder());

            return ms.ToArray();
        }
    }
}