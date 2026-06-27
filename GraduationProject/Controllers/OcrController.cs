using System.Text.RegularExpressions;
using GraduationProject.Contracts.MedicalTests;
using GraduationProject.Contracts.OCR;
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
            var testType = analysis.TestType; // auto-detected by AnalysisService

            // If OCR couldn't read any real values, return 200 with IsValidScan=false
            // so the frontend receives a structured response instead of treating it as a crash.
            // Nothing is saved to the database in this case.
            if (!analysis.IsValidScan)
            {
                return Ok(new
                {
                    extractedText  = text,
                    analysis,
                    medicalTest    = (object?)null,
                    patientSummary = (string?)null,
                });
            }

            object? createdTest = null;

            if (patientId.HasValue && labId.HasValue)
            {
                // Build pipe-separated "Name: value (Status)" string.
                // Omit the status label when Normal so _TestTile chips stay clean.
                // UnreadableValue entries are skipped — they have no usable value.
                var resultStr = string.Join(" | ",
                    analysis.Tests
                        .Where(t => t.Status != "UnreadableValue")
                        .Select(t => t.Status == "Normal"
                            ? $"{t.Name}: {t.Value}"
                            : $"{t.Name}: {t.Value} ({t.Status})"));

                var request = new MedicalTestRequest(
                    testType,
                    resultStr,
                    patientId.Value,
                    labId.Value);

                var saveResult = await _medicalTestService.AddAsync(request, cancellationToken);

                if (!saveResult.IsSuccess)
                    return saveResult.ToProblem();

                // Save the original image alongside the result
                var ext          = Path.GetExtension(image.FileName);
                var safeType     = Regex.Replace(testType.ToLowerInvariant(), @"[^a-z0-9]", "-");
                var fileName     = $"{safeType}-{saveResult.Value.Id}{ext}";
                var relativePath = await _fileService.SaveFileAsync(bytes, "uploads/lab-reports", fileName);

                await _medicalTestService.UpdateImagePathAsync(
                    saveResult.Value.Id, relativePath, cancellationToken);

                createdTest = saveResult.Value with { ImageUrl = $"/{relativePath}" };
            }

            return Ok(new
            {
                extractedText  = text,
                analysis,
                medicalTest    = createdTest,
                patientSummary = GeneratePatientSummary(analysis),
            });
        }

        private static string GeneratePatientSummary(AnalysisResult analysis)
        {
            var abnormal = analysis.Tests
                .Where(t => t.Status == "High" || t.Status == "Low")
                .ToList();

            if (!abnormal.Any())
                return "✅ All your test results are within the normal range. Keep up the healthy lifestyle!";

            var lines     = new List<string>();
            var lowItems  = abnormal.Where(t => t.Status == "Low").ToList();
            var highItems = abnormal.Where(t => t.Status == "High").ToList();

            if (lowItems.Any())
            {
                var names = string.Join(", ", lowItems.Select(t => t.Name));
                lines.Add($"⬇️ Low levels detected in: {names}. These may need attention.");
            }

            if (highItems.Any())
            {
                var names = string.Join(", ", highItems.Select(t => t.Name));
                lines.Add($"⬆️ High levels detected in: {names}. Please consult your doctor.");
            }

            lines.Add("📋 We recommend sharing these results with your doctor for proper evaluation.");
            return string.Join("\n", lines);
        }
    }
}
