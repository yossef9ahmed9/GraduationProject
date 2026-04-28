

using GraduationProject.Contracts.Patients;


namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class PatientsController(IPatientService patientService) : ControllerBase
    {
        private readonly IPatientService _patientService = patientService;

        [HttpGet("")]
        public async Task<IActionResult> GetPatients(CancellationToken cancellationToken)
        {
            var patients = await _patientService.GetAllPatientsAsync(cancellationToken);
            var response = patients.Adapt<IEnumerable<PatientResponse>>();

            return Ok(response);
        }


        [HttpGet("{id}")]
        public async Task<IActionResult> GetPatient([FromRoute] int id, CancellationToken cancellationToken)
        {
            var patient =await _patientService.GetPatientAsync(id, cancellationToken);

            if (patient == null)
            {
                return NotFound();
            }
            var response = patient.Adapt<PatientResponse>();
            return Ok(response);

        }
        [HttpPost]
        public async Task<IActionResult> CreatePatient([FromBody] PatientRequest request, CancellationToken cancellationToken)
        {
            var patient = request.Adapt<Patient>();
            var newpatient = await _patientService.AddPatientAsync (patient,cancellationToken);
            return CreatedAtAction(nameof(GetPatient), new { id = newpatient.Id }, newpatient);
        }

        [HttpPut("{id}")]
        public async  Task<IActionResult> UpdatePatient([FromRoute] int id, [FromBody] PatientRequest request, CancellationToken cancellationToken)
        {
            var patient = request.Adapt<Patient>();
            var updated = await _patientService.UpdatePatientAsync(id, patient,cancellationToken);
            if (!updated)
            {
                return NotFound();
            }
            return NoContent();
        }
       
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeletePatient([FromRoute] int id, CancellationToken cancellationToken)
        {
            var deleted =await _patientService.DeletePatientAsync(id, cancellationToken);
            if (!deleted)
            {
                return NotFound();
            }
            return NoContent();
        }
    }
}