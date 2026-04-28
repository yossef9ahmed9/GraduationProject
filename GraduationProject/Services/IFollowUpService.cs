namespace GraduationProject.Services
{
    public interface IFollowUpService
    {
        Task<IEnumerable<FollowUp>> GetAllAsync();
        Task<FollowUp> AddAsync(FollowUp followUp);
    }
}