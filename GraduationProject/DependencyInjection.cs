



using GraduationProject.Services.OCR;

namespace GraduationProject
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddProjectServices(this IServiceCollection services,IConfiguration configuration)
        {

            
            services.AddControllers();
            services.AddAuthConfig();
            services.AddFluentValidationsConfig();
            services.AddSwaggerConfig();
            services.AddExceptionHandler<GlobalExceptionHandler>();
            services.AddProblemDetails();

            var connectionString = configuration.GetConnectionString("DefaultConnection") ??
                throw new InvalidOperationException("Connection string 'DefaultConnection' not found.");

            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(connectionString));


            // Add application services
            services.AddScoped<IPatientService, PatientService>();
            services.AddScoped<IAuthService, AuthService>();
            services.AddScoped<IDoctorService, DoctorService>();
            services.AddScoped<ISensorService, SensorService>();
            services.AddScoped<IVitalSignsService, VitalSignsService>();
            services.AddScoped<IFollowUpService, FollowUpService>();
            services.AddScoped<ILabService, LabService>();
            services.AddScoped<IMedicalTestService, MedicalTestService>();
            services.AddScoped<IFileService, FileService>();
            services.AddScoped<IOcrService, OcrService>();
            services.AddScoped<IAnalysisService, AnalysisService>();
      

            //mapster
            var mapingConfig = TypeAdapterConfig.GlobalSettings;
            mapingConfig.Scan(Assembly.GetExecutingAssembly());


            return services;
        }




        private static IServiceCollection AddSwaggerConfig(this IServiceCollection services)
        {

            //swagger
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();


            return services;
        }
        private static IServiceCollection AddFluentValidationsConfig(this IServiceCollection services)
        {

            //FluentValidation
            services
                .AddValidatorsFromAssembly(Assembly.GetExecutingAssembly())
                .AddFluentValidationAutoValidation();
            return services;
        }

        private static IServiceCollection AddAuthConfig(this IServiceCollection services)
        {

            services.AddSingleton<IJwtProvider,JwtProvider>(); 

            services.AddIdentity<ApplicationUser,IdentityRole>()
                .AddEntityFrameworkStores<AppDbContext>();

            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            })
                .AddJwtBearer(o =>
                {
                    o.SaveToken = true;
                    o.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuerSigningKey = true,
                        ValidateIssuer = true,
                        ValidateAudience = true,
                        ValidateLifetime = true,
                        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes("7lxKQWrP1jN54i6/ns6eQp0oNdKSNDOLyuids0kxoVI=")),
                        ValidAudience = "GraduationProject users",
                        ValidIssuer= "GraduationProjectApp"

                    };
                });
            return services;
        }

    }
}
