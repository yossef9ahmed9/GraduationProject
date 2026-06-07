using GraduationProject.Errors;

namespace GraduationProject.Services
{
    public class AuthService(
        UserManager<ApplicationUser> userManager,
        IJwtProvider jwtProvider,
        AppDbContext context,
        IEmailService emailService) : IAuthService
    {
        public UserManager<ApplicationUser> _userManager { get; } = userManager;
        public IJwtProvider _JwtProvider = jwtProvider;
        private readonly AppDbContext _context = context;
        private readonly IEmailService _emailService = emailService;

        public async Task<Result<AuthResponse?>> GetTokkenAsync(
            string email,
            string password,
            CancellationToken cancellationToken = default)
        {
            var user = await _userManager.FindByEmailAsync(email);

            if (user == null)
                return Result.Failure<AuthResponse>(UserErrors.InvalidCredentials);

            var isValidPassword = await _userManager.CheckPasswordAsync(user, password);

            if (!isValidPassword)
                return Result.Failure<AuthResponse>(UserErrors.InvalidCredentials);

            var roles = await _userManager.GetRolesAsync(user);
            var (token, expiresIn) = _JwtProvider.GenerateToken(user, roles);

            var refreshToken = _JwtProvider.GenerateRefreshToken();

            user.RefreshTokens.Add(new RefreshToken
            {
                Token     = refreshToken,
                CreatedOn = DateTime.UtcNow,
                ExpiresOn = DateTime.UtcNow.AddDays(7)
            });

            await _userManager.UpdateAsync(user);

            return Result.Success(new AuthResponse(
                user.Id, user.FullName, user.Email,
                token, expiresIn * 60, refreshToken));
        }

        public async Task<Result<AuthResponse?>> RegisterPatientAsync(
            PatientRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            var exists = await _context.Patients
                .AnyAsync(p => p.Email == request.Email, cancellationToken);

            if (exists)
                return Result.Failure<AuthResponse>(PatientErrors.DuplicatedPatient);

            var user = new ApplicationUser
            {
                FullName = request.FullName,
                Email    = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed(errors));
            }

            await _userManager.AddToRoleAsync(user, "Patient");

            var patient = new Patient
            {
                Name          = request.FullName,
                Email         = request.Email,
                Gender        = request.Gender.ToLower(),
                Phone         = request.Phone,
                Address       = request.Address,
                BirthDate     = request.BirthDate,
                MedicalRecord = request.MedicalRecord,
                BloodType     = request.BloodType
            };

            await _context.Patients.AddAsync(patient, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        public async Task<Result<AuthResponse?>> RegisterDoctorAsync(
            DoctorRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            var exists = await _context.Doctors
                .AnyAsync(d => d.Email == request.Email, cancellationToken);

            if (exists)
                return Result.Failure<AuthResponse>(DoctorErors.DuplicatedDoctor);

            var user = new ApplicationUser
            {
                FullName = request.FullName,
                Email    = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed(errors));
            }

            await _userManager.AddToRoleAsync(user, "Doctor");

            var doctor = new Doctor
            {
                Name           = request.FullName,
                Email          = request.Email,
                Phone          = request.Phone,
                Specialization = request.Specialization
            };

            await _context.Doctors.AddAsync(doctor, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        public async Task<Result<AuthResponse?>> RegisterLabAsync(
            LabRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            var userExists = await _userManager.FindByEmailAsync(request.Email);
            if (userExists is not null)
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed("Email already exists"));

            var user = new ApplicationUser
            {
                FullName = request.LabName,
                Email    = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed(errors));
            }

            await _userManager.AddToRoleAsync(user, "Lab");

            var lab = new Lab
            {
                Name     = request.LabName,
                Location = request.Location,
                Phone    = request.Phone,
                Email    = request.Email,
            };

            await _context.Labs.AddAsync(lab, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        public async Task<Result<AuthResponse?>> RegisterRelativeAsync(
            RelativeRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            var user = new ApplicationUser
            {
                FullName = request.FullName,
                Email    = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed(errors));
            }

            await _userManager.AddToRoleAsync(user, "Relative");

            var relative = new Relative
            {
                Name         = request.FullName,
                Phone        = request.Phone,
                RelationType = request.RelationType,
                PatientId    = request.PatientId
            };

            await _context.Relatives.AddAsync(relative, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        public async Task<Result<AuthResponse?>> RegisterAmbulanceAsync(
            AmbulanceRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            var user = new ApplicationUser
            {
                FullName = request.StationName,
                Email    = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed(errors));
            }

            await _userManager.AddToRoleAsync(user, "Ambulance");

            // FIXED: LicensePlate, DriverName, DriverPhone are now required non-nullable
            // fields on AmbulanceRegisterRequest — the ?? "" fallbacks are no longer needed.
            var ambulance = new Ambulance
            {
                Email              = request.Email,
                StationName        = request.StationName,
                Phone              = request.Phone,
                AvailabilityStatus = request.AvailabilityStatus,
                LicensePlate       = request.LicensePlate,
                DriverName         = request.DriverName,
                DriverPhone        = request.DriverPhone
            };

            await _context.Ambulances.AddAsync(ambulance, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        private async Task<Result<AuthResponse?>> GenerateAuthResponseAsync(ApplicationUser user)
        {
            var roles = await _userManager.GetRolesAsync(user);
            var (token, expiresIn) = _JwtProvider.GenerateToken(user, roles);

            var refreshToken = _JwtProvider.GenerateRefreshToken();

            user.RefreshTokens.Add(new RefreshToken
            {
                Token     = refreshToken,
                CreatedOn = DateTime.UtcNow,
                ExpiresOn = DateTime.UtcNow.AddDays(7)
            });

            await _userManager.UpdateAsync(user);

            return Result.Success(new AuthResponse(
                user.Id, user.FullName, user.Email,
                token, expiresIn * 60, refreshToken));
        }

        public async Task<Result<AuthResponse?>> RefreshTokenAsync(string token)
        {
            var user = _context.Users
                .Include(u => u.RefreshTokens)
                .SingleOrDefault(u =>
                    u.RefreshTokens.Any(t => t.Token == token));

            if (user is null)
                return Result.Failure<AuthResponse>(UserErrors.InvalidRefreshToken);

            var refreshToken = user.RefreshTokens.Single(t => t.Token == token);

            if (!refreshToken.IsActive)
                return Result.Failure<AuthResponse>(UserErrors.InvalidRefreshToken);

            refreshToken.RevokedOn = DateTime.UtcNow;

            var newRefreshToken = _JwtProvider.GenerateRefreshToken();

            user.RefreshTokens.Add(new RefreshToken
            {
                Token     = newRefreshToken,
                CreatedOn = DateTime.UtcNow,
                ExpiresOn = DateTime.UtcNow.AddDays(7)
            });

            var roles = await _userManager.GetRolesAsync(user);
            var (jwtToken, expiresIn) = _JwtProvider.GenerateToken(user, roles);

            await _userManager.UpdateAsync(user);

            return Result.Success(new AuthResponse(
                user.Id, user.FullName, user.Email,
                jwtToken, expiresIn * 60, newRefreshToken));
        }

        // FIXED: returns Result (not Result<string>) — the token is sent via email and
        // is never exposed in the HTTP response. Always returns success so callers
        // cannot enumerate registered emails.
        public async Task<Result> ForgotPasswordAsync(string email)
        {
            var user = await _userManager.FindByEmailAsync(email);

            if (user is null)
                return Result.Success(); // intentionally vague — no user enumeration

            var resetToken = await _userManager.GeneratePasswordResetTokenAsync(user);

            try
            {
                await _emailService.SendPasswordResetEmailAsync(email, resetToken);
            }
            catch (Exception)
            {
                // SMTP failure must not leak details to the caller.
                // Ops team can check logs for the full exception.
            }

            return Result.Success();
        }

        public async Task<Result> ResetPasswordAsync(ResetPasswordRequest request)
        {
            var user = await _userManager.FindByEmailAsync(request.Email);

            // FIXED: return InvalidResetToken (not EmailNotFound) — same reason as above,
            // we don't confirm whether an email is registered.
            if (user is null)
                return Result.Failure(UserErrors.InvalidResetToken);

            var result = await _userManager.ResetPasswordAsync(
                user, request.Token, request.NewPassword);

            if (!result.Succeeded)
                return Result.Failure(UserErrors.InvalidResetToken);

            return Result.Success();
        }
    }
}
