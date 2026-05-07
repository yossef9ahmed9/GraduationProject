

namespace GraduationProject.Presistence.EntitiesConfigurations
{
    public class PatientConfiguration : IEntityTypeConfiguration<Patient>
    {
        public void Configure(EntityTypeBuilder<Patient> builder)
        {

         builder.HasKey(p => p.Id);

         builder.Property(p => p.Name)
                .IsRequired()
                .HasMaxLength(100);

         builder.Property(p => p.Email)
                .HasMaxLength(150);

         builder.HasIndex(p=>p.Email)
            .IsUnique();

         builder.Property(p => p.Phone)
                .HasMaxLength(11);


            builder.Property(p => p.Gender)
                .IsRequired()
                .HasMaxLength(10);


         builder.HasCheckConstraint(
                "CK_Patient_Gender",
                "Gender IN ('male','female')");
        }




           
     }
}
