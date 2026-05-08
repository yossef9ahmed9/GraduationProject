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
        public DbSet<EmergencyDispatch> EmergencyDispatches { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.ApplyConfigurationsFromAssembly(
                Assembly.GetExecutingAssembly());

            base.OnModelCreating(modelBuilder);

            // NEW: apply Restrict globally to ALL foreign keys automatically
            // this means nothing deletes by accident unless we explicitly say Cascade
            // no need to write OnDelete(Restrict) in every single configuration file again
            foreach (var relationship in modelBuilder.Model
                .GetEntityTypes()
                .SelectMany(e => e.GetForeignKeys()))
            {
                relationship.DeleteBehavior = DeleteBehavior.Restrict;
            }

            // NEW: now ONLY override the ones we actually want to cascade
            // meaning: if you delete a Patient, delete everything that belongs to them

            // Patient deleted → delete their VitalSigns
            modelBuilder.Entity<VitalSigns>()
                .HasOne(v => v.Patient)
                .WithMany(p => p.VitalSigns)
                .HasForeignKey(v => v.PatientId)
                .OnDelete(DeleteBehavior.Cascade);

            // Patient deleted → delete their Sensors
            modelBuilder.Entity<Sensor>()
                .HasOne(s => s.Patient)
                .WithMany(p => p.Sensors)
                .HasForeignKey(s => s.PatientId)
                .OnDelete(DeleteBehavior.Cascade);

            // Patient deleted → delete their Relatives
            modelBuilder.Entity<Relative>()
                .HasOne(r => r.Patient)
                .WithMany(p => p.Relatives)
                .HasForeignKey(r => r.PatientId)
                .OnDelete(DeleteBehavior.Cascade);

            // Patient deleted → delete their MedicalTests
            modelBuilder.Entity<MedicalTest>()
                .HasOne(m => m.Patient)
                .WithMany(p => p.MedicalTests)
                .HasForeignKey(m => m.PatientId)
                .OnDelete(DeleteBehavior.Cascade);

            // Patient deleted → delete their FollowUps
            modelBuilder.Entity<FollowUp>()
                .HasOne(f => f.Patient)
                .WithMany(p => p.FollowUps)
                .HasForeignKey(f => f.PatientId)
                .OnDelete(DeleteBehavior.Cascade);

            // Patient deleted → delete their EmergencyDispatches
            modelBuilder.Entity<EmergencyDispatch>()
                .HasOne(e => e.Patient)
                .WithMany(p => p.EmergencyDispatches)
                .HasForeignKey(e => e.PatientId)
                .OnDelete(DeleteBehavior.Cascade);

            // Sensor deleted → Restrict VitalSigns (patient cascade covers this already)
            // we leave this as Restrict from the global rule above
            // so if sensor deleted alone, it wont delete vitals by accident

            // User deleted → delete their RefreshTokens
            modelBuilder.Entity<RefreshToken>()
                .HasOne(r => r.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}