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
                Token = refreshToken,
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
                Email = request.Email,
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
                Name      = request.FullName,
                Email     = request.Email,
                Gender    = request.Gender.ToLower(),
                Phone     = request.Phone,
                Address   = request.Address,
                BirthDate = request.BirthDate,
                MedicalRecord = request.MedicalRecord,
                BloodType = "Unknown"
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
                Phone    = request.Phone
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

            var ambulance = new Ambulance
            {
                StationName        = request.StationName,
                Phone              = request.Phone,
                AvailabilityStatus = request.AvailabilityStatus,
                // FIXED: LicensePlate, DriverName, DriverPhone are now required strings
                // in AmbulanceRegisterRequest — no nullable fallback needed
                LicensePlate = request.LicensePlate,
                DriverName   = request.DriverName,
                DriverPhone  = request.DriverPhone
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
                .SingleOrDefault(u => u.RefreshTokens.Any(t => t.Token == token));

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

        public async Task<Result> ForgotPasswordAsync(string email)
        {
            // FIXED: the old implementation returned the raw reset token in the HTTP response,
            // which completely defeats the security purpose of the flow.
            // The token must be delivered out-of-band (email) — never in the API response.
            // We return the same generic message regardless of whether the email exists
            // to prevent user enumeration attacks.
            var user = await _userManager.FindByEmailAsync(email);

            if (user is not null)
            {
                var resetToken = await _userManager.GeneratePasswordResetTokenAsync(user);

                // Deliver the token via email, never via the HTTP response.
                await _emailService.SendPasswordResetEmailAsync(user.Email!, resetToken);
            }

            // Always return success — do not reveal whether the email exists.
            return Result.Success();
        }

        public async Task<Result> ResetPasswordAsync(ResetPasswordRequest request)
        {
            var user = await _userManager.FindByEmailAsync(request.Email);

            if (user is null)
                return Result.Failure(UserErrors.InvalidResetToken); // don't reveal "email not found"

            var result = await _userManager.ResetPasswordAsync(
                user, request.Token, request.NewPassword);

            if (!result.Succeeded)
                return Result.Failure(UserErrors.InvalidResetToken);

            return Result.Success();
        }
    }
}
