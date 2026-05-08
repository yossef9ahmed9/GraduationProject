using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Processing;
using Image = SixLabors.ImageSharp.Image;

namespace GraduationProject.Services.OCR
{
    public static class ImagePreprocessor
    {
        public static byte[] Enhance(byte[] input)
        {
            using var image = Image.Load(input);

            // FIXED: smarter resize — only upscale small images
            // upscaling a large image wastes memory and hurts OCR
            int targetWidth = image.Width < 1000
                ? image.Width * 2
                : image.Width;

            int targetHeight = image.Height < 1000
                ? image.Height * 2
                : image.Height;

            image.Mutate(x =>
            {
                x.Resize(targetWidth, targetHeight);

                // convert to grayscale — OCR works better on grayscale
                x.Grayscale();

                // FIXED: lower contrast value — 1.8 was too aggressive
                // it was destroying thin characters like dots and commas
                x.Contrast(1.3f);

                // FIXED: lower sharpen value — 1.2 was adding noise
                x.GaussianSharpen(0.8f);

                // NEW: brightness adjustment helps with dark scanned reports
                x.Brightness(1.1f);
            });

            using var ms = new MemoryStream();
            image.Save(ms, new PngEncoder());
            return ms.ToArray();
        }
    }
}