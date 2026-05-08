namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class VitalSignsConfiguration : IEntityTypeConfiguration<VitalSigns>
    {
        public void Configure(EntityTypeBuilder<VitalSigns> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.HeartRate)
                .IsRequired();

            builder.Property(x => x.TimeStamp)
                .IsRequired();

            // NOTE: OnDelete is NOT set here anymore
            // Sensor → VitalSigns is Restrict (handled globally in AppDbContext)
            // Patient → VitalSigns is Cascade (handled explicitly in AppDbContext)
            builder.HasOne(x => x.Sensor)
                .WithMany(x => x.VitalSigns)
                .HasForeignKey(x => x.SensorId);

            builder.HasOne(x => x.Patient)
                .WithMany(x => x.VitalSigns)
                .HasForeignKey(x => x.PatientId);
        }
    }
}