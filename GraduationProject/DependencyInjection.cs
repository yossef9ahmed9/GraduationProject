using GraduationProject.Services.OCR;

namespace GraduationProject
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddProjectServices(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddControllers();

            // UPDATED: passing configuration down so AddAuthConfig can read JwtOptions from it
            services.AddAuthConfig(configuration);

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

            // UPDATED: registered EmergencyDispatchService — it had an entity, migrations,
            // and a DbSet but no service or controller wired up, making the whole feature unreachable
            services.AddScoped<IEmergencyDispatchService, EmergencyDispatchService>();

            // NEW: registered AutoEmergencyService — evaluates each incoming vital-signs
            // reading against critical thresholds and dispatches the nearest available
            // ambulance automatically when values are dangerously abnormal.
            // Registered as Scoped because it shares the same DbContext lifetime as the
            // VitalSignsService that calls it.
            services.AddScoped<IAutoEmergencyService, AutoEmergencyService>();

            // mapster
            var mapingConfig = TypeAdapterConfig.GlobalSettings;
            mapingConfig.Scan(Assembly.GetExecutingAssembly());

            return services;
        }

        private static IServiceCollection AddSwaggerConfig(this IServiceCollection services)
        {
            // swagger
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();

            return services;
        }

        private static IServiceCollection AddFluentValidationsConfig(this IServiceCollection services)
        {
            // FluentValidation
            services
                .AddValidatorsFromAssembly(Assembly.GetExecutingAssembly())
                .AddFluentValidationAutoValidation();

            return services;
        }

        // UPDATED: now takes IConfiguration so we can read JWT settings from appsettings.json
        // instead of having the key, issuer, audience hardcoded in both JwtProvider and here
        private static IServiceCollection AddAuthConfig(this IServiceCollection services, IConfiguration configuration)
        {
            // UPDATED: register JwtOptions so IOptions<JwtOptions> can be injected into JwtProvider
            // this binds the "Jwt" section in appsettings.json to the JwtOptions class
            services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));

            services.AddSingleton<IJwtProvider, JwtProvider>();

            services.AddIdentity<ApplicationUser, IdentityRole>()
                .AddEntityFrameworkStores<AppDbContext>();

            // UPDATED: read JWT settings from config instead of hardcoding them here
            // previously the key, issuer, and audience were duplicated (hardcoded here AND in JwtProvider)
            // now both places read from the same source: appsettings.json
            var jwtOptions = configuration
                .GetSection(JwtOptions.SectionName)
                .Get<JwtOptions>()!;

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
                    IssuerSigningKey = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(jwtOptions.Key)),
                    ValidAudience = jwtOptions.Audience,
                    ValidIssuer = jwtOptions.Issuer
                };
            });

            return services;
        }
    }
}
