namespace GraduationProject.Entities
{
    public class Patient
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;

        public string Gender { get; set; } = string.Empty;

        public string Phone { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;

        public string Address { get; set; } = string.Empty;

        public DateOnly BirthDate { get; set; }

        public string MedicalRecord { get; set; } = string.Empty;

        public ICollection<Relative> Relatives { get; set; }
            = new List<Relative>();

        public ICollection<Sensor> Sensors { get; set; }
            = new List<Sensor>();

        public ICollection<MedicalTest> MedicalTests { get; set; }
            = new List<MedicalTest>();

        public ICollection<FollowUp> FollowUps { get; set; }
            = new List<FollowUp>();
    }
}