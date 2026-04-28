namespace GraduationProject.Entities
{
    public class Doctor
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Phone { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string Specialization { get; set; } = string.Empty;

        public ICollection<FollowUp> FollowUps { get; set; }
            = new List<FollowUp>();
    }
}
