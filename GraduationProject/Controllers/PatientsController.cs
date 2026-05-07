

using GraduationProject.Contracts.Patients;


namespace GraduationProject.Controllers
{

[Route("api/[controller]")]
[ApiController]
[Authorize]
public class PatientsController(IPatientService patientService) : ControllerBase
{
    private readonly IPatientService _patientService = patientService;

    [HttpGet]
    public async Task<IActionResult> GetPatients(CancellationToken cancellationToken)
    {
        return Ok(await _patientService.GetAllPatientsAsync(cancellationToken));
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetPatient(int id, CancellationToken cancellationToken)
    {
        var result = await _patientService.GetPatientAsync(id, cancellationToken);

        return result.IsSuccess
            ? Ok(result.Value)
            : result.ToProblem();
    }

    [HttpPost]
    public async Task<IActionResult> CreatePatient(PatientRequest request, CancellationToken cancellationToken)
    {
        var result = await _patientService.AddPatientAsync(request, cancellationToken);

        return result.IsSuccess
            ? CreatedAtAction(nameof(GetPatient), new { id = result.Value.Id }, result.Value)
            : result.ToProblem();
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdatePatient(int id, PatientRequest request, CancellationToken cancellationToken)
    {
        var result = await _patientService.UpdatePatientAsync(id, request, cancellationToken);

        return result.IsSuccess
            ? NoContent()
            : result.ToProblem();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeletePatient(int id, CancellationToken cancellationToken)
    {
        var result = await _patientService.DeletePatientAsync(id, cancellationToken);

        return result.IsSuccess
            ? NoContent()
            : result.ToProblem();
    }
} 
}