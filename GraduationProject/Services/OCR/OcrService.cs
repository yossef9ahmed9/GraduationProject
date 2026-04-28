using GraduationProject.Services.OCR;
using Tesseract;

namespace GraduationProject.Services
{
    public class OcrService : IOcrService
    {
        public string ExtractText(byte[] imageBytes)
        {
            var tessPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "tessdata");

            // 🔥 تحسين الصورة قبل OCR
            imageBytes = ImagePreprocessor.Enhance(imageBytes);

            using var engine = new TesseractEngine(tessPath, "eng", EngineMode.LstmOnly);

            // 🔥 إعدادات مهمة لتحسين قراءة الجداول
            engine.SetVariable("tessedit_pageseg_mode", "6");
            engine.SetVariable("preserve_interword_spaces", "1");
            engine.SetVariable("classify_bln_numeric_mode", "1");

            using var img = Pix.LoadFromMemory(imageBytes);

            using var page = engine.Process(img);

            return page.GetText();
        }
    }
}