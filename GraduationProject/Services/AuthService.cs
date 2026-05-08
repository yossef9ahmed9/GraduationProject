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

        public async Task<Result<AuthResponse?>> RegisterAsync(
            RegisterRequest request,
            CancellationToken cancellationToken = default)
        {
            // create the identity user
            var user = new ApplicationUser
            {
                FullName = request.FullName,
                Email = request.Email,
                UserName = request.Email
            };

            var result = await _userManager.CreateAsync(user, request.Password);

            if (!result.Succeeded)
                return Result.Failure<AuthResponse>(UserErrors.RegistrationFailed);

            // assign role
            await _userManager.AddToRoleAsync(user, request.Role);

            // NEW: create the matching entity record based on role
            var entityResult = await CreateRoleEntityAsync(request, cancellationToken);
            if (!entityResult.IsSuccess)
            {
                // NEW: if entity creation fails, delete the user we just made to keep data clean
                await _userManager.DeleteAsync(user);
                return Result.Failure<AuthResponse>(entityResult.Error);
            }

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

        // NEW: creates the actual entity record depending on the role
        private async Task<Result> CreateRoleEntityAsync(
            RegisterRequest request,
            CancellationToken cancellationToken)
        {
            var role = request.Role.ToLower();

            if (role == "patient")
            {
                // NEW: check no duplicate patient email
                var exists = await _context.Patients
                    .AnyAsync(p => p.Email == request.Email, cancellationToken);

                if (exists)
                    return Result.Failure(PatientErrors.DuplicatedPatient);

                // NEW: create Patient record from registration data
                var patient = new Patient
                {
                    Name = request.FullName,
                    Email = request.Email,
                    Gender = request.Gender!,
                    Phone = request.Phone!,
                    Address = request.Address!,
                    BirthDate = request.BirthDate!.Value,
                    MedicalRecord = request.MedicalRecord!
                };

                await _context.Patients.AddAsync(patient, cancellationToken);
                await _context.SaveChangesAsync(cancellationToken);
            }
            else if (role == "doctor")
            {
                // NEW: check no duplicate doctor email
                var exists = await _context.Doctors
                    .AnyAsync(d => d.Email == request.Email, cancellationToken);

                if (exists)
                    return Result.Failure(DoctorErors.DuplicatedDoctor);

                // NEW: create Doctor record from registration data
                var doctor = new Doctor
                {
                    Name = request.FullName,
                    Email = request.Email,
                    Phone = request.Phone!,
                    Specialization = request.Specialization!
                };

                await _context.Doctors.AddAsync(doctor, cancellationToken);
                await _context.SaveChangesAsync(cancellationToken);
            }
            else if (role == "lab")
            {
                // NEW: create Lab record from registration data
                var lab = new Lab
                {
                    Name = request.LabName!,
                    Location = request.Location!,
                    Phone = request.Phone!
                };

                await _context.Labs.AddAsync(lab, cancellationToken);
                await _context.SaveChangesAsync(cancellationToken);
            }
            else if (role == "relative")
            {
                // NEW: create Relative record from registration data
                var relative = new Relative
                {
                    Name = request.FullName,
                    Phone = request.Phone!,
                    RelationType = request.RelationType!,
                    PatientId = request.PatientId!.Value
                };

                await _context.Relatives.AddAsync(relative, cancellationToken);
                await _context.SaveChangesAsync(cancellationToken);
            }
            else if (role == "ambulance")
            {
                // NEW: create Ambulance record from registration data
                var ambulance = new Ambulance
                {
                    StationName = request.StationName!,
                    Phone = request.Phone!,
                    AvailabilityStatus = request.AvailabilityStatus!
                };

                await _context.Ambulances.AddAsync(ambulance, cancellationToken);
                await _context.SaveChangesAsync(cancellationToken);
            }

            return Result.Success();
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