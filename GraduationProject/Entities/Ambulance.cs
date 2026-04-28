namespace GraduationProject.Entities
{
    public class Ambulance
    {
        public int Id { get; set; }

        public string StationName { get; set; } = string.Empty;

        public string Phone { get; set; } = string.Empty;

        public string AvailabilityStatus { get; set; } = string.Empty;
    }
}
