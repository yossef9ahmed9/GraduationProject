// ============================================================
// File: GraduationProject/Services/HeartRiskService.cs
// ============================================================
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using GraduationProject.Contracts.HeartRisk;

namespace GraduationProject.Services
{
    /// <summary>
    /// Calls the MAX30102 FastAPI micro-service over HTTP.
    /// The base URL is read from appsettings.json: "HeartRiskApi:BaseUrl"
    /// Default: http://localhost:8000
    /// </summary>
    public class HeartRiskService(
     IHttpClientFactory httpClientFactory,
     IConfiguration configuration,
     ILogger<HeartRiskService> logger,
     AppDbContext context) : IHeartRiskService
    {
        private readonly HttpClient _http = httpClientFactory.CreateClient();
        private readonly ILogger _logger = logger;
        private readonly AppDbContext _context = context;

        // runs once when the service is created
        private readonly string _baseUrl =
            configuration["HeartRiskApi:BaseUrl"] ?? "http://127.0.0.1:8000";

        // ── JSON options shared across all calls ──────────────────────────────
        private static readonly JsonSerializerOptions _jsonOpts = new()
        {
            PropertyNamingPolicy        = JsonNamingPolicy.SnakeCaseLower,
            DefaultIgnoreCondition      = JsonIgnoreCondition.WhenWritingNull,
            PropertyNameCaseInsensitive = true,
        };

        // ─────────────────────────────────────────────────────────────────────
        // Single prediction
        // ─────────────────────────────────────────────────────────────────────
        public async Task<Result<HeartRiskResponse>> PredictAsync(
            HeartRiskRequest request,
            CancellationToken cancellationToken = default)
        {
            try
            {
                // Python model expects snake_case JSON keys
                var payload = new
                {
                    bpm    = request.Bpm,
                    spo2   = request.Spo2,
                    hrv_ms = request.HrvMs,
                    age    = request.Age,
                    sex    = request.Sex,
                };
                var response = await _http.PostAsJsonAsync($"{_baseUrl}/predict", payload, _jsonOpts, cancellationToken);

 

                if (!response.IsSuccessStatusCode)
                    return Result.Failure<HeartRiskResponse>(HeartRiskErrors.ServiceUnavailable);

                var raw = await response.Content.ReadFromJsonAsync<PythonPredictionDto>(
                    _jsonOpts, cancellationToken);

                return raw is null
                    ? Result.Failure<HeartRiskResponse>(HeartRiskErrors.InvalidResponse)
                    : Result.Success(MapToResponse(raw));
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "HeartRiskService — cannot reach Python API");
                return Result.Failure<HeartRiskResponse>(HeartRiskErrors.ServiceUnavailable);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "HeartRiskService — unexpected error in PredictAsync: {Message} | {StackTrace}", ex.Message, ex.StackTrace);
                return Result.Failure<HeartRiskResponse>(new Error(
                    "HeartRisk.InternalError",
                    ex.Message,
                    500));
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // 30-second window prediction
        // ─────────────────────────────────────────────────────────────────────
        public async Task<Result<HeartRiskResponse>> PredictWindowAsync(
            HeartRiskWindowRequest request,
            CancellationToken cancellationToken = default)
        {
            try
            {
                var payload = new
                {
                    bpm_avg  = request.BpmAvg,
                    bpm_min  = request.BpmMin,
                    bpm_max  = request.BpmMax,
                    spo2_avg = request.Spo2Avg,
                    spo2_min = request.Spo2Min,
                    hrv_ms   = request.HrvMs,
                    age      = request.Age,
                    sex      = request.Sex,
                };
                var response = await _http.PostAsJsonAsync($"{_baseUrl}/predict/window", payload, _jsonOpts, cancellationToken);
                

                if (!response.IsSuccessStatusCode)
                    return Result.Failure<HeartRiskResponse>(HeartRiskErrors.ServiceUnavailable);

                var raw = await response.Content.ReadFromJsonAsync<PythonPredictionDto>(
                    _jsonOpts, cancellationToken);

                return raw is null
                    ? Result.Failure<HeartRiskResponse>(HeartRiskErrors.InvalidResponse)
                    : Result.Success(MapToResponse(raw));
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "HeartRiskService — cannot reach Python API (window)");
                return Result.Failure<HeartRiskResponse>(HeartRiskErrors.ServiceUnavailable);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "HeartRiskService — unexpected error in PredictWindowAsync");
                return Result.Failure<HeartRiskResponse>(HeartRiskErrors.InternalError);
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Batch prediction
        // ─────────────────────────────────────────────────────────────────────
        public async Task<Result<HeartRiskBatchResponse>> PredictBatchAsync(
            HeartRiskBatchRequest request,
            CancellationToken cancellationToken = default)
        {
            try
            {
                var payload = new
                {
                    readings = request.Readings.Select(r => new
                    {
                        bpm    = r.Bpm,
                        spo2   = r.Spo2,
                        hrv_ms = r.HrvMs,
                        age    = r.Age,
                        sex    = r.Sex,
                    }).ToList()
                };

                var response = await _http.PostAsJsonAsync($"{_baseUrl}/predict/batch", payload, _jsonOpts, cancellationToken);


                if (!response.IsSuccessStatusCode)
                    return Result.Failure<HeartRiskBatchResponse>(HeartRiskErrors.ServiceUnavailable);

                var raw = await response.Content
                    .ReadFromJsonAsync<PythonBatchResponseDto>(_jsonOpts, cancellationToken);

                if (raw is null)
                    return Result.Failure<HeartRiskBatchResponse>(HeartRiskErrors.InvalidResponse);

                var items = raw.Results.Select(r => new HeartRiskBatchItem(
                    r.Index,
                    r.Tier,
                    r.Score,
                    r.Alert,
                    r.Action,
                    r.OverrideReason,
                    r.Error
                )).ToList();

                return Result.Success(new HeartRiskBatchResponse(
                    raw.Total,
                    raw.CriticalCount,
                    raw.WarningCount,
                    raw.NormalCount,
                    items));
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "HeartRiskService — cannot reach Python API (batch)");
                return Result.Failure<HeartRiskBatchResponse>(HeartRiskErrors.ServiceUnavailable);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "HeartRiskService — unexpected error in PredictBatchAsync");
                return Result.Failure<HeartRiskBatchResponse>(HeartRiskErrors.InternalError);
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Health check
        // ─────────────────────────────────────────────────────────────────────
        public async Task<bool> IsHealthyAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                var response = await _http.GetAsync($"{_baseUrl}/health", cancellationToken);
               
                return response.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // Trend prediction — loads last 10 VitalSigns from DB then calls Python
        // ─────────────────────────────────────────────────────────────────────
        public async Task<Result<HeartRiskTrendResponse>> PredictTrendAsync(
            int patientId,
            CancellationToken cancellationToken = default)
        {
            try
            {
                // Pull last 10 readings for this patient, newest first
                var vitals = await _context.VitalSigns
                    .AsNoTracking()
                    .Include(v => v.Patient)
                    .Where(v => v.PatientId == patientId && !v.IsDeleted)
                    .OrderByDescending(v => v.TimeStamp)
                    .Take(10)
                    .ToListAsync(cancellationToken);

                if (vitals.Count < 3)
                    return Result.Failure<HeartRiskTrendResponse>(
                        new Error("HeartRisk.NotEnoughData",
                            "At least 3 readings are needed for trend analysis. Keep the sensor on.",
                            400));

                var patient = vitals.First().Patient;
                var now     = vitals.First().TimeStamp;

                // Build readings list with offset in seconds relative to latest
                var readings = vitals.Select(v => new
                {
                    bpm                   = (double)v.HeartRate,
                    spo2                  = v.OxygenSaturation,
                    timestamp_offset_sec  = (now - v.TimeStamp).TotalSeconds,
                }).ToList();

                int age = CalculateAge(patient.BirthDate);
                int sex = patient.Gender.ToLower() == "male" ? 1 : 0;

                var payload = new
                {
                    readings,
                    age,
                    sex,
                    hrv_ms = 50.0, // default — HRV not stored in VitalSigns yet
                };

                var response = await _http.PostAsJsonAsync(
                    $"{_baseUrl}/predict/trend", payload, _jsonOpts, cancellationToken);

                if (!response.IsSuccessStatusCode)
                    return Result.Failure<HeartRiskTrendResponse>(HeartRiskErrors.ServiceUnavailable);

                var raw = await response.Content
                    .ReadFromJsonAsync<TrendResponseDto>(_jsonOpts, cancellationToken);

                if (raw is null)
                    return Result.Failure<HeartRiskTrendResponse>(HeartRiskErrors.InvalidResponse);

                return Result.Success(new HeartRiskTrendResponse(
                    raw.CurrentTier,
                    raw.TrendDirection,
                    raw.BpmSlope,
                    raw.Spo2Slope,
                    raw.ForecastTier5Min,
                    raw.ForecastTier10Min,
                    raw.Alert,
                    raw.Message,
                    raw.Confidence,
                    raw.TimeToDangerMin
                ));
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "HeartRiskService — cannot reach Python API (trend)");
                return Result.Failure<HeartRiskTrendResponse>(HeartRiskErrors.ServiceUnavailable);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "HeartRiskService — unexpected error in PredictTrendAsync");
                return Result.Failure<HeartRiskTrendResponse>(HeartRiskErrors.InternalError);
            }
        }

        private static int CalculateAge(DateOnly birthDate)
        {
            var today = DateOnly.FromDateTime(DateTime.Today);
            var age   = today.Year - birthDate.Year;
            if (birthDate > today.AddYears(-age)) age--;
            return Math.Max(1, age);
        }

        // ─────────────────────────────────────────────────────────────────────
        // Mapping helpers
        // ─────────────────────────────────────────────────────────────────────
        private static HeartRiskResponse MapToResponse(PythonPredictionDto dto) =>
            new(
                dto.Tier,
                dto.Score,
                dto.Confidence,
                dto.Action,
                dto.Message,
                dto.Alert,
                dto.OverrideReason,
                new HeartRiskProbabilities(
                    dto.Probabilities?.Normal   ?? 0,
                    dto.Probabilities?.Warning  ?? 0,
                    dto.Probabilities?.Critical ?? 0
                )
            );

        // ─────────────────────────────────────────────────────────────────────
        // Internal DTOs — mirror the Python snake_case JSON exactly
        // ─────────────────────────────────────────────────────────────────────
        private sealed class PythonPredictionDto
        {
            public string  Tier            { get; set; } = string.Empty;
            public double  Score           { get; set; }
            public double  Confidence      { get; set; }
            public string  Action          { get; set; } = string.Empty;
            public string  Message         { get; set; } = string.Empty;
            public bool    Alert           { get; set; }
            public string? OverrideReason  { get; set; }
            public ProbDto? Probabilities  { get; set; }
        }

        private sealed class ProbDto
        {
            public double Normal   { get; set; }
            public double Warning  { get; set; }
            public double Critical { get; set; }
        }

        private sealed class PythonBatchResponseDto
        {
            public int              Total         { get; set; }
            public int              CriticalCount { get; set; }
            public int              WarningCount  { get; set; }
            public int              NormalCount   { get; set; }
            public List<BatchItemDto> Results     { get; set; } = new();
        }

        private sealed class BatchItemDto
        {
            public int     Index          { get; set; }
            public string? Tier           { get; set; }
            public double? Score          { get; set; }
            public bool?   Alert          { get; set; }
            public string? Action         { get; set; }
            public string? OverrideReason { get; set; }
            public string? Error          { get; set; }
        }

        private sealed class TrendResponseDto
        {
            public string CurrentTier         { get; set; } = string.Empty;
            public string TrendDirection       { get; set; } = string.Empty;
            public double BpmSlope             { get; set; }
            public double Spo2Slope            { get; set; }
            public string ForecastTier5Min     { get; set; } = string.Empty;
            public string ForecastTier10Min    { get; set; } = string.Empty;
            public bool   Alert                { get; set; }
            public string Message              { get; set; } = string.Empty;
            public double Confidence           { get; set; }
            public double? TimeToDangerMin     { get; set; }
        }
    }
}
