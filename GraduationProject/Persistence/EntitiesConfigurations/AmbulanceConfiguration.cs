namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class AmbulanceConfiguration : IEntityTypeConfiguration<Ambulance>
    {
        public void Configure(EntityTypeBuilder<Ambulance> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.Email)
                .IsRequired()
                .HasMaxLength(150);

            builder.Property(x => x.DriverName)
                .IsRequired()
                .HasMaxLength(100);

            builder.Property(x => x.DriverPhone)
                .IsRequired()
                .HasMaxLength(11);

            builder.Property(x => x.Phone)
                .HasMaxLength(11);

            builder.Property(x => x.AvailabilityStatus)
                .HasMaxLength(50);

            builder.Property(x => x.LicensePlate)
                .HasMaxLength(20);

            builder.Property(x => x.ServiceArea)
                .HasMaxLength(100);

            builder.Property(x => x.Latitude)
                .HasColumnType("float");

            builder.Property(x => x.Longitude)
                .HasColumnType("float");
        }
    }
}

