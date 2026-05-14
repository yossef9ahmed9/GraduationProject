

namespace GraduationProject.Services
{
    public class PatientService(AppDbContext context) : IPatientService
    {
       
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<PatientResponse>> GetAllPatientsAsync(CancellationToken cancellationToken = default) =>
            await _context.Patients.AsNoTracking().ProjectToType<PatientResponse>().ToListAsync(cancellationToken);




        public async Task<Result<PatientResponse>> GetPatientAsync(int id, CancellationToken cancellationToken=default)
        {
            var patient = await _context.Patients.FindAsync(id, cancellationToken);
            return patient == null ? Result.Failure<PatientResponse?>(PatientErrors.PatientNotFound) : Result.Success(patient.Adapt<PatientResponse>());
        }



        //        //public Patient AddPatient(Patient patient)
        //        //{
        //        //    patient.Id = _patients.Max(p => p.Id) + 1;
        //        //    _patients.Add(patient);
        //        //    return patient;
        //        //}   المشكله هنا ان لو الليست فاضى الكود هيشخرلى 

        
        public async Task<Result<PatientResponse>> AddPatientAsync( PatientRequest request,CancellationToken cancellationToken = default)
        {
            var exists = await _context.Patients
                .AnyAsync(p => p.Email == request.Email , cancellationToken);

            if (exists)
                return Result.Failure<PatientResponse>(PatientErrors.DuplicatedPatient);

            var newPatient = request.Adapt<Patient>();

            // UPDATED: normalize gender to lowercase before saving
            // the DB check constraint is: Gender IN ('male','female') — lowercase only
            // without this, inserting "Male" or "Female" from the request would throw a DB error
            newPatient.Gender = request.Gender.ToLower();

            await _context.Patients.AddAsync(newPatient, cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success(newPatient.Adapt<PatientResponse>());
        }



        public async Task<Result> UpdatePatientAsync(int id, PatientRequest request,CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients.FindAsync(  id , cancellationToken);

            if (patient == null)
                return Result.Failure(PatientErrors.PatientNotFound);

            var exists = await _context.Patients
                .AnyAsync(p => (p.Email == request.Email) && p.Id != id,cancellationToken);

            if (exists)
                return Result.Failure(PatientErrors.DuplicatedPatient);

            request.Adapt(patient);

            // UPDATED: normalize gender to lowercase after Adapt overwrites it
            // Adapt copies Gender as-is from the request, so we re-apply the lowercase fix here
            patient.Gender = request.Gender.ToLower();

            await _context.SaveChangesAsync(cancellationToken);

            return Result.Success();
        }

        public async Task<Result> DeletePatientAsync(int id, CancellationToken cancellationToken = default)
        {
            var patient = await _context.Patients.FindAsync(id, cancellationToken);
            if (patient == null)
            {
                return Result.Failure(PatientErrors.PatientNotFound);
            }
            _context.Patients.Remove(patient);
            await _context.SaveChangesAsync(cancellationToken);
            return Result.Success();
        }



    }
}
