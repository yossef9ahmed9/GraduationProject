namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class AmbulanceConfiguration : IEntityTypeConfiguration<Ambulance>
    {
        public void Configure(EntityTypeBuilder<Ambulance> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.StationName)
                .IsRequired()
                .HasMaxLength(100);

            builder.Property(x => x.Phone)
                .HasMaxLength(11);

            builder.Property(x => x.AvailabilityStatus)
                .HasMaxLength(50);
        }
    }
}

