
namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class DoctorConfiguration : IEntityTypeConfiguration<Doctor>
    {
        public void Configure(EntityTypeBuilder<Doctor> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.Name)
                .IsRequired()
                .HasMaxLength(100);

            builder.Property(x => x.Email)
                .HasMaxLength(150);

            builder.HasIndex(x => x.Email)
                .IsUnique();

            builder.Property(x => x.Phone)
                .HasMaxLength(11);

            builder.HasIndex(x => x.Phone)
                .IsUnique();

            builder.Property(x => x.Specialization)
                .IsRequired()
                .HasMaxLength(100);
        }
    }
}