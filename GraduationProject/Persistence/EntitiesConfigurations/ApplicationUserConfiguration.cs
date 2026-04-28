

namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class ApplicationUserConfiguration : IEntityTypeConfiguration<ApplicationUser>
    {
        public void Configure(EntityTypeBuilder<ApplicationUser> builder)
        {


         builder.Property(p => p.FullName)
                .IsRequired()
                .HasMaxLength(100);

        
        }           
     }
}
