
namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class RelativeConfiguration : IEntityTypeConfiguration<Relative>
    {
        public void Configure(EntityTypeBuilder<Relative> builder)
        {
            builder.HasKey(x => x.Id);

            builder.Property(x => x.Name)
                .IsRequired()
                .HasMaxLength(100);

            builder.Property(x => x.Phone)
                .HasMaxLength(11);

            builder.Property(x => x.RelationType)
                .IsRequired()
                .HasMaxLength(50);

            builder.HasOne(x => x.Patient)
                .WithMany(x => x.Relatives)
                .HasForeignKey(x => x.PatientId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}