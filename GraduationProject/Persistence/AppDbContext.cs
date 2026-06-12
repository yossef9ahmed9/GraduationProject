using System.Linq.Expressions;

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
        public DbSet<LabAppointment> LabAppointments { get; set; }
        public DbSet<ChatMessage> ChatMessages { get; set; }
        public DbSet<RelativePatientRequest> RelativePatientRequests { get; set; }
        public DbSet<MedicalRecordEntry> MedicalRecordEntries { get; set; }
        public DbSet<Rating> Ratings { get; set; }

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

            // Relative.PatientId removed — relationship is now purely via PatientRequests

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

            // Soft delete global filter — applies to every entity that implements ISoftDeletable
            // any query automatically excludes deleted records unless you explicitly use IgnoreQueryFilters()
            foreach (var entityType in modelBuilder.Model
                .GetEntityTypes()
                .Where(e => typeof(ISoftDeletable).IsAssignableFrom(e.ClrType)))
            {
                var parameter = Expression.Parameter(entityType.ClrType, "e");
                var isDeletedProperty = Expression.Property(parameter, nameof(ISoftDeletable.IsDeleted));
                var notExpression = Expression.Not(isDeletedProperty);
                var lambda = Expression.Lambda(notExpression, parameter);

                modelBuilder.Entity(entityType.ClrType).HasQueryFilter(lambda);
            }

            // MedicalRecordEntry — history of all medical record changes with author info
            modelBuilder.Entity<MedicalRecordEntry>(b =>
            {
                b.HasKey(x => x.Id);
                b.Property(x => x.AuthorEmail).IsRequired().HasMaxLength(200);
                b.Property(x => x.AuthorName).IsRequired().HasMaxLength(100);
                b.Property(x => x.AuthorRole).IsRequired().HasMaxLength(50);
                b.Property(x => x.MedicalRecord).HasMaxLength(2000);
                b.Property(x => x.ChronicDiseases).HasMaxLength(500);
                b.Property(x => x.Allergies).HasMaxLength(500);
                b.Property(x => x.BloodType).HasMaxLength(10);
                b.HasOne(x => x.Patient)
                    .WithMany()
                    .HasForeignKey(x => x.PatientId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // RelativePatientRequest configuration
            modelBuilder.Entity<RelativePatientRequest>(b =>
            {
                b.HasKey(x => x.Id);

                b.Property(x => x.Status)
                    .IsRequired()
                    .HasMaxLength(20);

                b.HasOne(x => x.Relative)
                    .WithMany(r => r.PatientRequests)
                    .HasForeignKey(x => x.RelativeId)
                    .OnDelete(DeleteBehavior.Cascade);

                b.HasOne(x => x.Patient)
                    .WithMany()
                    .HasForeignKey(x => x.PatientId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // Make Relative.PatientId nullable — REMOVED (PatientId dropped from Relative entity)

            // User deleted → delete their RefreshTokens
            modelBuilder.Entity<RefreshToken>()
                .HasOne(r => r.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            // 2. Add this inside OnModelCreating (with the other entity configurations):
            modelBuilder.Entity<LabAppointment>(b =>
            {
                b.HasKey(x => x.Id);

                b.Property(x => x.TestNames)
                    .IsRequired()
                    .HasMaxLength(500);

                b.Property(x => x.Notes)
                    .HasMaxLength(1000);

                b.Property(x => x.Status)
                    .IsRequired()
                    .HasMaxLength(20);

                b.HasOne(x => x.Patient)
                    .WithMany()
                    .HasForeignKey(x => x.PatientId)
                    .OnDelete(DeleteBehavior.Cascade);

                b.HasOne(x => x.Lab)
                    .WithMany()
                    .HasForeignKey(x => x.LabId)
                    .OnDelete(DeleteBehavior.Restrict);
            });

            // Rating — one patient rating per target (doctor or lab), upsert semantics
            modelBuilder.Entity<Rating>(b =>
            {
                b.HasKey(x => x.Id);

                b.Property(x => x.Stars)
                    .IsRequired();

                b.HasOne(x => x.Patient)
                    .WithMany()
                    .HasForeignKey(x => x.PatientId)
                    .OnDelete(DeleteBehavior.Cascade);

                b.HasOne(x => x.Doctor)
                    .WithMany()
                    .HasForeignKey(x => x.DoctorId)
                    .OnDelete(DeleteBehavior.Restrict);

                b.HasOne(x => x.Lab)
                    .WithMany()
                    .HasForeignKey(x => x.LabId)
                    .OnDelete(DeleteBehavior.Restrict);

                // Unique: one rating per patient per doctor
                b.HasIndex(x => new { x.PatientId, x.DoctorId })
                    .IsUnique()
                    .HasFilter("[DoctorId] IS NOT NULL");

                // Unique: one rating per patient per lab
                b.HasIndex(x => new { x.PatientId, x.LabId })
                    .IsUnique()
                    .HasFilter("[LabId] IS NOT NULL");
            });

        }
    }
}