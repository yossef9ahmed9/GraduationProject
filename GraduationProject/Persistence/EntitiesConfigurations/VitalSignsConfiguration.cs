namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class VitalSignsConfiguration : IEntityTypeConfiguration<VitalSigns>
    {
        public void Configure(EntityTypeBuilder<VitalSigns> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.HeartRate)
                .IsRequired();

            builder.Property(x => x.OxygenSaturation)
                .IsRequired();

            builder.Property(x => x.TimeStamp)
                .IsRequired();

            builder.HasOne(x => x.Sensor)
                .WithMany(x => x.VitalSigns)
                .HasForeignKey(x => x.SensorId);

            builder.HasOne(x => x.Patient)
                .WithMany(x => x.VitalSigns)
                .HasForeignKey(x => x.PatientId);
        }
    }
}