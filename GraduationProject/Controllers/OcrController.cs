using System.Text.Json;
using GraduationProject.Contracts.MedicalTests;
using GraduationProject.Services.OCR;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
   [Authorize]
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
            [FromQuery] int? labId = null,
            CancellationToken cancellationToken = default)
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

                var saveResult = await _medicalTestService.AddAsync(request, cancellationToken);

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
