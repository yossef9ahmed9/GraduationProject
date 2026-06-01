# Fix Summary — GraduationProject

## How to apply
Replace the files listed below with the corresponding files from this patch.
Each section explains what was wrong and what changed.

---

## 1. JWT secret / credentials in source control
**Files:** `appsettings.json` → `DependencyInjection.cs`

`appsettings.json` had a hardcoded SQL Server connection string with username and
password, and the JWT key was read only from config (also committed to the repo).

**Fix:**
- `appsettings.json` — all secret values replaced with empty strings. Commit this
  file; it now serves only as a template.
- `DependencyInjection.cs` — all secrets are read from **environment variables first**,
  falling back to `appsettings.json` for local development only.

| Secret | Env variable |
|--------|-------------|
| DB connection string | `DB_CONNECTION_STRING` |
| JWT signing key | `JWT_KEY` |
| JWT issuer | `JWT_ISSUER` |
| JWT audience | `JWT_AUDIENCE` |
| JWT expiry (minutes) | `JWT_EXPIRY_MINUTES` |
| Refresh token expiry (days) | `JWT_REFRESH_EXPIRY_DAYS` |

The app will throw a clear `InvalidOperationException` on startup if a required
secret is missing, instead of silently using an empty key.

---

## 2. OcrController — [Authorize] was commented out
**File:** `Controllers/OcrController.cs`

The `[Authorize]` attribute was present but commented out, leaving the OCR upload
endpoint open to unauthenticated callers who could write arbitrary MedicalTest
records into the database.

**Fix:** `[Authorize]` restored.

---

## 3. ForgotPassword returns reset token in HTTP response
**Files:** `Services/AuthService.cs` → `Services/IAuthService.cs` → `Controllers/AuthController.cs`
**New file:** `Services/IEmailService.cs`

The old implementation called `_userManager.GeneratePasswordResetTokenAsync` and
returned the raw token in `Result<string>`, which was then exposed directly in the
200 OK response body. Anyone who intercepts the response (or has access to logs)
could use the token to take over any account.

**Fix:**
- `IEmailService` interface added. Wire up a concrete implementation (SendGrid,
  SMTP, etc.) and register it in `DependencyInjection.cs`.
- `ForgotPasswordAsync` now calls `_emailService.SendPasswordResetEmailAsync` and
  returns `Result` (no token in the response).
- The controller always returns the same 200 message regardless of whether the
  email exists, preventing user enumeration.
- `ResetPasswordAsync` now returns `UserErrors.InvalidResetToken` (not
  `UserErrors.EmailNotFound`) on unknown email, for the same reason.

**You must register IEmailService** before the app will compile:
```csharp
// In DependencyInjection.cs, inside AddProjectServices:
services.AddScoped<IEmailService, YourConcreteEmailService>();
```

---

## 4. VitalSignsService — silently swallows emergency dispatch failures
**File:** `Services/VitalSignsService.cs`

The original `catch (Exception ex)` block called `_logger.LogError` and returned
success regardless of what went wrong. A patient in critical condition could have
had no ambulance dispatched with no reliable trace.

**Fix:**
- `OperationCanceledException` is re-thrown (request was cancelled — don't suppress).
- Other exceptions are still caught (so the vital reading isn't lost), but the log
  message now says explicitly "Manual review required" and includes both the vital
  signs ID and the patient ID.
- `AutoDispatch` in the response is now populated with the real dispatch result.
  Previously it was always `null` even when an ambulance was dispatched.

---

## 5. OCR false alerts from EnsureCompleteTests
**File:** `Services/OCR/AnalysisService.cs`

`EnsureCompleteTests` padded every lab test that wasn't found in the image with
`Value = 0`. Every undetected test then triggered a "Low" alert. For a typical
CBC image where only 8 of 14 tests were readable, you'd get 6 spurious Low alerts.

**Fix:** `EnsureCompleteTests` removed entirely. `Analyze` now only reports tests
that were actually extracted from the image. If the OCR missed a test it simply
won't appear in `result.Tests` — no phantom alerts.

---

## 6. PatientRequest missing BloodType / ChronicDiseases / Allergies
**Files:** `Contracts/Patients/PatientRequest.cs` → `Services/PatientService.cs`

These three fields existed on the `Patient` entity and were included in
`PatientResponse`, but were absent from `PatientRequest`. Calling
`PUT /api/patients/{id}` would silently ignore them, making them permanently
read-only after the initial registration default was set.

**Fix:** All three fields added to `PatientRequest` with safe defaults
(`BloodType = "Unknown"`, others `null`) so existing callers don't break.
Mapster's `Adapt` copies them automatically — no manual code needed.

---

## 7. AmbulanceRegisterRequest — driver fields were nullable
**Files:** `Contracts/Authentication/AmbulanceRegisterRequest.cs`
           `Contracts/Authentication/AmbulanceRegisterRequestValidator.cs`

`LicensePlate`, `DriverName`, and `DriverPhone` were `string?` with empty-string
fallbacks in `AuthService`. Every registered ambulance started with no driver info.

**Fix:** All three are now required `string` fields. The validator enforces them
as `NotEmpty`. `AuthService` no longer needs the `?? ""` fallbacks.

---

## 8. DoctorResponse / RelativeResponse / SensorResponse
All three records already contained the correct fields. No changes needed beyond
confirming they match the entity. The files in this patch are identical to the
originals — included for completeness.

---

## Remaining to-do (out of scope for this patch)

- **Wire up `IEmailService`** — required before the app compiles after fix #3.
  Recommended: `MailKit` for SMTP or the official `SendGrid` NuGet package.
- **SignalR / push notifications** — relatives and doctors are not notified when
  `AutoEmergencyService` dispatches an ambulance. Consider a SignalR hub.
- **Rate limiting** on `/api/auth/login` — no brute-force protection currently.
- **Refresh token rotation** — old tokens are revoked but not pruned from the DB.
