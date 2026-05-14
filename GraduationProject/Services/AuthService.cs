using GraduationProject.Errors;

namespace GraduationProject.Services
{
    public class AuthService(
        UserManager<ApplicationUser> userManager,
        IJwtProvider jwtProvider,
        AppDbContext context) : IAuthService
    {
        public UserManager<ApplicationUser> _userManager { get; } = userManager;
        public IJwtProvider _JwtProvider = jwtProvider;
        private readonly AppDbContext _context = context;

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

        // UPDATED: replaced single RegisterAsync with separate methods per role
        // each method creates the identity user + the matching entity record
        // no more big if/else chain based on role string

        // NEW: register a patient — creates ApplicationUser + Patient entity
        public async Task<Result<AuthResponse?>> RegisterPatientAsync(
            PatientRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            // check no duplicate patient email in the Patients table
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

            // assign the Patient role
            await _userManager.AddToRoleAsync(user, "Patient");

            // create the Patient entity record
            var patient = new Patient
            {
                Name = request.FullName,
                Email = request.Email,
                Gender = request.Gender,
                Phone = request.Phone,
                Address = request.Address,
                BirthDate = request.BirthDate,
                MedicalRecord = request.MedicalRecord,
                   // UPDATED: defaulted to Unknown so patient can update it later
                // via PUT /api/patients/{id}
                BloodType = "Unknown"
            };

            await _context.Patients.AddAsync(patient, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        // NEW: register a doctor — creates ApplicationUser + Doctor entity
        public async Task<Result<AuthResponse?>> RegisterDoctorAsync(
            DoctorRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            // check no duplicate doctor email in the Doctors table
            var exists = await _context.Doctors
                .AnyAsync(d => d.Email == request.Email, cancellationToken);

            if (exists)
                return Result.Failure<AuthResponse>(DoctorErors.DuplicatedDoctor);

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

            // assign the Doctor role
            await _userManager.AddToRoleAsync(user, "Doctor");

            // create the Doctor entity record
            var doctor = new Doctor
            {
                Name = request.FullName,
                Email = request.Email,
                Phone = request.Phone,
                Specialization = request.Specialization
            };

            await _context.Doctors.AddAsync(doctor, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        // NEW: register a lab — creates ApplicationUser + Lab entity
        public async Task<Result<AuthResponse?>> RegisterLabAsync(
            LabRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            // labs use LabName as display name since they have no FullName field
            var user = new ApplicationUser
            {
                FullName = request.LabName,
                Email = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed(errors));
            }

            // assign the Lab role
            await _userManager.AddToRoleAsync(user, "Lab");

            // create the Lab entity record
            var lab = new Lab
            {
                Name = request.LabName,
                Location = request.Location,
                Phone = request.Phone
            };

            await _context.Labs.AddAsync(lab, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        // NEW: register a relative — creates ApplicationUser + Relative entity
        public async Task<Result<AuthResponse?>> RegisterRelativeAsync(
            RelativeRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
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

            // assign the Relative role
            await _userManager.AddToRoleAsync(user, "Relative");

            // create the Relative entity record
            var relative = new Relative
            {
                Name = request.FullName,
                Phone = request.Phone,
                RelationType = request.RelationType,
                PatientId = request.PatientId
            };

            await _context.Relatives.AddAsync(relative, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        // NEW: register an ambulance — creates ApplicationUser + Ambulance entity
        public async Task<Result<AuthResponse?>> RegisterAmbulanceAsync(
            AmbulanceRegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            // ambulances use StationName as display name since they have no FullName field
            var user = new ApplicationUser
            {
                FullName = request.StationName,
                Email = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed(errors));
            }

            // assign the Ambulance role
            await _userManager.AddToRoleAsync(user, "Ambulance");

            // create the Ambulance entity record
            var ambulance = new Ambulance
            {
                StationName = request.StationName,
                Phone = request.Phone,
                AvailabilityStatus = request.AvailabilityStatus
            };

            await _context.Ambulances.AddAsync(ambulance, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return await GenerateAuthResponseAsync(user);
        }

        // NEW: private helper — generates the JWT + refresh token after any successful registration
        // extracted to avoid repeating the same 10 lines in every register method
        private async Task<Result<AuthResponse?>> GenerateAuthResponseAsync(ApplicationUser user)
        {
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
                Token = newRefreshToken,
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

        public async Task<Result<string>> ForgotPasswordAsync(string email)
        {
            var user = await _userManager.FindByEmailAsync(email);

            if (user is null)
                return Result.Failure<string>(UserErrors.EmailNotFound);

            var resetToken = await _userManager.GeneratePasswordResetTokenAsync(user);

            return Result.Success(resetToken);
        }

        public async Task<Result> ResetPasswordAsync(ResetPasswordRequest request)
        {
            var user = await _userManager.FindByEmailAsync(request.Email);

            if (user is null)
                return Result.Failure(UserErrors.EmailNotFound);

            var result = await _userManager.ResetPasswordAsync(
                user, request.Token, request.NewPassword);

            if (!result.Succeeded)
                return Result.Failure(UserErrors.InvalidResetToken);

            return Result.Success();
        }
    }
}