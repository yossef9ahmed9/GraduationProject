namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class SensorConfiguration : IEntityTypeConfiguration<Sensor>
    {
        public void Configure(EntityTypeBuilder<Sensor> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.Type)
                .IsRequired()
                .HasMaxLength(50);

            builder.Property(x => x.Description)
                .HasMaxLength(200);

            // NOTE: no OnDelete here — Cascade is set in AppDbContext
            builder.HasOne(x => x.Patient)
                .WithMany(x => x.Sensors)
                .HasForeignKey(x => x.PatientId);
        }
    }
}