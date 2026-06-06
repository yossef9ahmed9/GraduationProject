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
        private readonly IFileService       _fileService        = fileService;
        private readonly IOcrService        _ocrService         = ocrService;
        private readonly IAnalysisService   _analysisService    = analysisService;
        private readonly IMedicalTestService _medicalTestService = medicalTestService;

        // Allowed MIME types for uploaded lab-report images
        private static readonly HashSet<string> _allowedContentTypes = new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg", "image/jpg", "image/png", "image/bmp", "image/tiff"
        };

        // 10 MB hard limit — larger files are almost certainly not lab-report photos
        private const long MaxFileSizeBytes = 10 * 1024 * 1024;

        [HttpPost]
        public async Task<IActionResult> Upload(
            IFormFile image,
            [FromQuery] int? patientId = null,
            [FromQuery] int? labId     = null,
            CancellationToken cancellationToken = default)
        {
            if (image == null || image.Length == 0)
                return BadRequest(new { message = "No image file was provided." });

            // Validate file size
            if (image.Length > MaxFileSizeBytes)
                return BadRequest(new { message = $"File size exceeds the {MaxFileSizeBytes / 1024 / 1024} MB limit." });

            // Validate content type
            if (!_allowedContentTypes.Contains(image.ContentType))
                return BadRequest(new { message = "Unsupported file type. Please upload a JPEG, PNG, BMP, or TIFF image." });

            if ((patientId.HasValue && !labId.HasValue) ||
                (!patientId.HasValue && labId.HasValue))
                return BadRequest(new { message = "Both patientId and labId must be provided together, or neither." });

            var bytes = await _fileService.GetBytesAsync(image);

            var text     = _ocrService.ExtractText(bytes);
            var analysis = _analysisService.Analyze(text);

            // If OCR couldn't read any real values, return 200 with IsValidScan=false
            // so the frontend receives a structured response instead of treating it as a crash.
            // Nothing is saved to the database in this case.
            if (!analysis.IsValidScan)
            {
                return Ok(new
                {
                    extractedText = text,
                    analysis,
                    medicalTest = (object?)null
                });
            }

            object? createdTest = null;

            if (patientId.HasValue && labId.HasValue)
            {
                var request = new MedicalTestRequest(
                    "CBC",
                    JsonSerializer.Serialize(analysis, new JsonSerializerOptions { WriteIndented = false }),
                    patientId.Value,
                    labId.Value);

                var saveResult = await _medicalTestService.AddAsync(request, cancellationToken);

                if (!saveResult.IsSuccess)
                    return saveResult.ToProblem();

                // Save the original image alongside the result so it can be reviewed later
                var ext          = Path.GetExtension(image.FileName);
                var fileName     = $"cbc-{saveResult.Value.Id}{ext}";
                var relativePath = await _fileService.SaveFileAsync(bytes, "uploads/lab-reports", fileName);

                await _medicalTestService.UpdateImagePathAsync(
                    saveResult.Value.Id, relativePath, cancellationToken);

                createdTest = saveResult.Value with { ImageUrl = $"/{relativePath}" };
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
