using System.Text.Json;
using GraduationProject.Contracts.MedicalTests;
using GraduationProject.Services.OCR;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
   // [Authorize]
    public class OcrController(
        IFileService fileService,
        IOcrService ocrService,
        IAnalysisService analysisService,
        IMedicalTestService medicalTestService) : ControllerBase
    {
        private readonly IFileService _fileService = fileService;
        private readonly IOcrService _ocrService = ocrService;
        private readonly IAnalysisService _analysisService = analysisService;
        private readonly IMedicalTestService _medicalTestService = medicalTestService;

        [HttpPost]
        public async Task<IActionResult> Upload(
            IFormFile image,
            [FromQuery] int? patientId = null,
            [FromQuery] int? labId = null)
        {
            if (image == null || image.Length == 0)
                return BadRequest("Invalid image");

            if ((patientId.HasValue && !labId.HasValue) ||
                (!patientId.HasValue && labId.HasValue))
                return BadRequest("Both patientId and labId must be provided together, or neither.");

            var bytes = await _fileService.GetBytesAsync(image);

            var text = _ocrService.ExtractText(bytes);

            var analysis = _analysisService.Analyze(text);

            object? createdTest = null;

            if (patientId.HasValue && labId.HasValue)
            {
                var request = new MedicalTestRequest(
                    "CBC",
                    JsonSerializer.Serialize(analysis, new JsonSerializerOptions { WriteIndented = false }),
                    patientId.Value,
                    labId.Value);

                // UPDATED: was missing CancellationToken — passing CancellationToken.None here
                // because the cancellation token from the action isn't easily threaded through
                // the local variable scope in this method without refactoring the whole flow
                var saveResult = await _medicalTestService.AddAsync(request, CancellationToken.None);

                if (saveResult.IsSuccess)
                    createdTest = saveResult.Value;
                else
                    return saveResult.ToProblem();
            }

            return Ok(new
            {
                extractedText = text,
                analysis,
                medicalTest = createdTest
            });
        }
    }
}
