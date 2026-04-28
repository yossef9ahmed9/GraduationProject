namespace GraduationProject.Presistence
{
    public class AppDbContext(DbContextOptions<AppDbContext> options)
        : IdentityDbContext<ApplicationUser>(options)
    {
        public DbSet<Patient> Patients { get; set; }

        public DbSet<Doctor> Doctors { get; set; }

        public DbSet<Relative> Relatives { get; set; }

        public DbSet<Ambulance> Ambulances { get; set; }

        public DbSet<Sensor> Sensors { get; set; }

        public DbSet<VitalSigns> VitalSigns { get; set; }

        public DbSet<Lab> Labs { get; set; }

        public DbSet<MedicalTest> MedicalTests { get; set; }

        public DbSet<FollowUp> FollowUps { get; set; }

        public DbSet<RefreshToken> RefreshTokens { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.ApplyConfigurationsFromAssembly(
                Assembly.GetExecutingAssembly());

            base.OnModelCreating(modelBuilder);
        }
    }
}