
namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class LabConfiguration : IEntityTypeConfiguration<Lab>
    {
        public void Configure(EntityTypeBuilder<Lab> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.Name)
                .IsRequired()
                .HasMaxLength(150);

            builder.Property(x => x.Location)
                .HasMaxLength(200);

            builder.Property(x => x.Phone)
                .HasMaxLength(11);
        }
    }
}