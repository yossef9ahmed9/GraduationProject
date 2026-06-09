using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    // UPDATED: added [Authorize] — this was the only controller missing it
    // anyone could POST fake vital signs without a token before this fix
    [Authorize]
    public class VitalSignsController(
        IVitalSignsService service,
        IAutoEmergencyService autoEmergency,
        AppDbContext context
        ) : ControllerBase
    {
        private readonly IVitalSignsService _service = service;
        private readonly IAutoEmergencyService _autoEmergency = autoEmergency;
        private readonly AppDbContext _context = context;

        [HttpGet]
        public async Task<IActionResult> Get([FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10, CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetAllAsync(pageNumber, pageSize, cancellationToken));
        }

        [HttpGet("patient/{patientId}")]
        public async Task<IActionResult> GetByPatient(
            int patientId,
            [FromQuery] int pageNumber = 1, [FromQuery] int pageSize = 10,
            CancellationToken cancellationToken = default)
        {
            return Ok(await _service.GetByPatientAsync(patientId, pageNumber, pageSize, cancellationToken));
        }

        // NEW: get only the most recent reading for a patient
        [HttpGet("patient/{patientId}/latest")]
        public async Task<IActionResult> GetLatestByPatient(
            int patientId,
            CancellationToken cancellationToken)
        {
            var result = await _service.GetLatestByPatientAsync(patientId, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        [HttpPost]
        [Authorize(Roles = "Patient")]
        public async Task<IActionResult> Create(
            VitalSignsRequest request,
            CancellationToken cancellationToken)
        {
            var email = User.FindFirst(System.Security.Claims.ClaimTypes.Email)?.Value
                     ?? User.FindFirst("email")?.Value;

            if (!string.IsNullOrEmpty(email))
            {
                var patient = await _context.Patients
                    .AsNoTracking()
                    .FirstOrDefaultAsync(p => p.Email == email, cancellationToken);

                if (patient is null || patient.Id != request.PatientId)
                    return Forbid();
            }

            var result = await _service.AddAsync(request, cancellationToken);

            return result.IsSuccess
                ? Ok(result.Value)
                : result.ToProblem();
        }

        // POST /api/vitalsigns/{id}/check-emergency
        // Admin-only: manually re-evaluates a saved reading and triggers dispatch if critical.
        // Emergency dispatch is normally triggered automatically by the sensor endpoint.
        [HttpPost("{id}/check-emergency")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> CheckEmergency(
            int id,
            CancellationToken cancellationToken)
        {
            var dispatch = await _autoEmergency.TryTriggerEmergencyAsync(id, cancellationToken);

            return dispatch is null
                ? Ok(new { message = "No emergency triggered. Values are within safe thresholds or an emergency is already active." })
                : Ok(new { message = "Emergency dispatch created.", dispatch });
        }

        // POST /api/vitalsigns/sensor
        // Called directly by ESP32/Arduino — no user auth required.
        // Accepts { patientId, heartRate, oxygenSaturation } only (no sensorId).
        // Automatically resolves or creates a sensor record for the patient,
        // then saves the reading and triggers auto-emergency if values are critical.
        [HttpPost("sensor")]
        [AllowAnonymous]
        public async Task<IActionResult> PostFromSensor(
            [FromBody] SensorVitalRequest request,
            CancellationToken cancellationToken)
        {
            // Verify patient exists
            var patientExists = await _context.Patients
                .AnyAsync(p => p.Id == request.PatientId, cancellationToken);

            if (!patientExists)
                return NotFound(new { message = "Patient not found." });

            // Get existing sensor for this patient, or create one automatically
            var sensor = await _context.Sensors
                .FirstOrDefaultAsync(s => s.PatientId == request.PatientId && !s.IsDeleted, cancellationToken);

            if (sensor is null)
            {
                sensor = new Sensor
                {
                    PatientId   = request.PatientId,
                    Type        = "MAX30102",
                    Description = "Auto-registered sensor",
                    IsActive    = true,
                    LastPing    = DateTime.UtcNow,
                };
                await _context.Sensors.AddAsync(sensor, cancellationToken);
                await _context.SaveChangesAsync(cancellationToken);
            }

            // Build the standard request and reuse the full service pipeline
            // (saves reading + runs AutoEmergencyService + FCM notifications)
            var vitalRequest = new VitalSignsRequest(
                HeartRate:        request.HeartRate,
                OxygenSaturation: request.OxygenSaturation,
                SensorId:         sensor.Id,
                PatientId:        request.PatientId);

            var result = await _service.AddAsync(vitalRequest, cancellationToken);

            if (!result.IsSuccess)
                return result.ToProblem();

            var saved = result.Value;
            return Ok(new
            {
                id           = saved.Id,
                heartRate    = saved.HeartRate,
                spo2         = saved.OxygenSaturation,
                isEmergency  = saved.EmergencyStatus,
                autoDispatch = saved.AutoDispatch is not null,
                savedAt      = saved.TimeStamp,
            });
        }
    }
}
