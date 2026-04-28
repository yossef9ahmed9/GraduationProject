using GraduationProject.Contracts.FollowUps;

namespace GraduationProject.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class FollowUpsController(IFollowUpService service) : ControllerBase
    {
        private readonly IFollowUpService _service = service;

        [HttpGet]
        public async Task<IActionResult> Get()
            => Ok(await _service.GetAllAsync());

        [HttpPost]
        public async Task<IActionResult> Create(FollowUpRequest request)
        {
            var followUp = await _service.AddAsync(request.Adapt<FollowUp>());
            return Ok(followUp);
        }
    }
}