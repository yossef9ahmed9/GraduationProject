using GraduationProject.Services.OCR;
using Tesseract;

namespace GraduationProject.Services
{
    public class OcrService : IOcrService
    {
        public string ExtractText(byte[] imageBytes)
        {
            var tessPath = Path.Combine(
                AppDomain.CurrentDomain.BaseDirectory, "tessdata");

            imageBytes = ImagePreprocessor.Enhance(imageBytes);

            using var engine = new TesseractEngine(
                tessPath, "eng", EngineMode.LstmOnly);

            // FIXED: page seg mode 6 = single uniform block of text
            // changed to 4 = single column of text — better for lab reports
            // which are usually single-column tables
            engine.SetVariable("tessedit_pageseg_mode", "4");

            // keep spaces between words
            engine.SetVariable("preserve_interword_spaces", "1");

            // FIXED: removed classify_bln_numeric_mode
            // it was forcing numeric interpretation on text fields
            // causing test names to be misread

            // NEW: whitelist the characters we expect in lab reports
            // this reduces misreads significantly
            engine.SetVariable(
                "tessedit_char_whitelist",
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,- /():%+");

            using var img = Pix.LoadFromMemory(imageBytes);
            using var page = engine.Process(img);

            return page.GetText();
        }
    }
}