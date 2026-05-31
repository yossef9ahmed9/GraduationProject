using GraduationProject.Services.OCR;

namespace GraduationProject
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddProjectServices(this IServiceCollection services, IConfiguration configuration)
        {
            services.AddControllers();

            services.AddAuthConfig(configuration);

            services.AddFluentValidationsConfig();
            services.AddSwaggerConfig();
            services.AddExceptionHandler<GlobalExceptionHandler>();
            services.AddProblemDetails();

            var connectionString =
                Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")
                ?? configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException(
                    "Database connection string not configured. " +
                    "Set the DB_CONNECTION_STRING environment variable.");

            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlServer(connectionString));

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
            services.AddScoped<IEmergencyDispatchService, EmergencyDispatchService>();
            services.AddScoped<IAutoEmergencyService, AutoEmergencyService>();

            var mappingConfig = TypeAdapterConfig.GlobalSettings;
            mappingConfig.Scan(Assembly.GetExecutingAssembly());

            return services;
        }

        private static IServiceCollection AddSwaggerConfig(this IServiceCollection services)
        {
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen(c =>
            {
                c.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
                {
                    Name = "Authorization",
                    Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
                    Scheme = "Bearer",
                    BearerFormat = "JWT",
                    In = Microsoft.OpenApi.Models.ParameterLocation.Header,
                    Description = "Enter your JWT token."
                });
                c.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
                {
                    {
                        new Microsoft.OpenApi.Models.OpenApiSecurityScheme
                        {
                            Reference = new Microsoft.OpenApi.Models.OpenApiReference
                            {
                                Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                                Id = "Bearer"
                            }
                        },
                        Array.Empty<string>()
                    }
                });
            });

            return services;
        }

        private static IServiceCollection AddFluentValidationsConfig(this IServiceCollection services)
        {
            services
                .AddValidatorsFromAssembly(Assembly.GetExecutingAssembly())
                .AddFluentValidationAutoValidation();

            return services;
        }

        private static IServiceCollection AddAuthConfig(this IServiceCollection services, IConfiguration configuration)
        {
            // JWT secret and settings MUST come from environment variables in production.
            // Environment variables override appsettings.json values automatically via
            // the default ASP.NET Core configuration pipeline (ASPNETCORE_ prefix or
            // double-underscore notation: Jwt__Key, Jwt__Issuer, etc.)
            services.Configure<JwtOptions>(opts =>
            {
                opts.Key        = Environment.GetEnvironmentVariable("JWT_KEY")
                                  ?? configuration["Jwt:Key"]
                                  ?? throw new InvalidOperationException(
                                      "JWT signing key not configured. Set the JWT_KEY environment variable.");

                opts.Issuer     = Environment.GetEnvironmentVariable("JWT_ISSUER")
                                  ?? configuration["Jwt:Issuer"]
                                  ?? throw new InvalidOperationException(
                                      "JWT issuer not configured. Set the JWT_ISSUER environment variable.");

                opts.Audience   = Environment.GetEnvironmentVariable("JWT_AUDIENCE")
                                  ?? configuration["Jwt:Audience"]
                                  ?? throw new InvalidOperationException(
                                      "JWT audience not configured. Set the JWT_AUDIENCE environment variable.");

                opts.ExpiryMinutes = int.TryParse(
                    Environment.GetEnvironmentVariable("JWT_EXPIRY_MINUTES"), out var exp)
                    ? exp
                    : configuration.GetValue<int>("Jwt:ExpiryMinutes", 60);

                opts.RefreshTokenExpiryDays = int.TryParse(
                    Environment.GetEnvironmentVariable("JWT_REFRESH_EXPIRY_DAYS"), out var ref_)
                    ? ref_
                    : configuration.GetValue<int>("Jwt:RefreshTokenExpiryDays", 7);
            });

            services.AddSingleton<IJwtProvider, JwtProvider>();

            services.AddIdentity<ApplicationUser, IdentityRole>()
                .AddEntityFrameworkStores<AppDbContext>()
                .AddDefaultTokenProviders();

            // Re-resolve the key for AddJwtBearer (IOptions not yet available here)
            var jwtKey = Environment.GetEnvironmentVariable("JWT_KEY")
                         ?? configuration["Jwt:Key"]
                         ?? throw new InvalidOperationException("JWT_KEY not configured.");

            var jwtIssuer   = Environment.GetEnvironmentVariable("JWT_ISSUER")   ?? configuration["Jwt:Issuer"]   ?? "";
            var jwtAudience = Environment.GetEnvironmentVariable("JWT_AUDIENCE") ?? configuration["Jwt:Audience"] ?? "";

            services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme    = JwtBearerDefaults.AuthenticationScheme;
            })
            .AddJwtBearer(o =>
            {
                o.SaveToken = true;
                o.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    ValidateIssuer           = true,
                    ValidateAudience         = true,
                    ValidateLifetime         = true,
                    IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
                    ValidAudience            = jwtAudience,
                    ValidIssuer              = jwtIssuer
                };
            });

            return services;
        }
    }
}
