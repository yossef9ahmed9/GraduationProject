using GraduationProject.Services.OCR;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
   // [Authorize]
    public class OcrController(
        IFileService fileService,
        IOcrService ocrService,
        IAnalysisService analysisService) : ControllerBase
    {
        private readonly IFileService _fileService = fileService;
        private readonly IOcrService _ocrService = ocrService;
        private readonly IAnalysisService _analysisService = analysisService;

        [HttpPost]
        public async Task<IActionResult> Upload(IFormFile image)
        {
            if (image == null || image.Length == 0)
                return BadRequest("Invalid image");

            var bytes = await _fileService.GetBytesAsync(image);

            var text = _ocrService.ExtractText(bytes);

            var result = _analysisService.Analyze(text);

            return Ok(new
            {
                extractedText = text,
                analysis = result
            });
        }
    }
}