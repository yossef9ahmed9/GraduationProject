using GraduationProject.Contracts.VitalSigns;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class VitalSignsController(IVitalSignsService service) : ControllerBase
    {
        private readonly IVitalSignsService _service = service;

        [HttpGet]
        public async Task<IActionResult> Get()
            => Ok(await _service.GetAllAsync());

        [HttpPost]
        public async Task<IActionResult> Create(VitalSignsRequest request)
        {
            var vital = await _service.AddAsync(request.Adapt<VitalSigns>());
            return Ok(vital);
        }
    }
}