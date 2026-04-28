

namespace GraduationProject.Services
{
    public class PatientService(AppDbContext context) : IPatientService
    {
       
        private readonly AppDbContext _context = context;

        public async Task<IEnumerable<Patient>> GetAllPatientsAsync(CancellationToken cancellationToken = default) =>
            await _context.Patients.AsNoTracking().ToListAsync(cancellationToken);




        public async Task<Patient> GetPatientAsync(int id, CancellationToken cancellationToken=default) => 
            await _context.Patients.FindAsync(id, cancellationToken);



        //        //public Patient AddPatient(Patient patient)
        //        //{
        //        //    patient.Id = _patients.Max(p => p.Id) + 1;
        //        //    _patients.Add(patient);
        //        //    return patient;
        //        //}   المشكله هنا ان لو الليست فاضى الكود هيشخرلى 

        public async Task<Patient> AddPatientAsync(Patient patient,CancellationToken cancellationToken = default)
        {
           

           await _context.Patients.AddAsync(patient,cancellationToken);
            await _context.SaveChangesAsync(cancellationToken);
            return patient;
        }

        public async Task<bool> UpdatePatientAsync(int id, Patient patient, CancellationToken cancellationToken=default)
        {
            var existingPatient =await GetPatientAsync(id,cancellationToken);
            if (existingPatient == null)
            {
                return false;
            }
            existingPatient.Name = patient.Name;
            existingPatient.BirthDate = patient.BirthDate;
            existingPatient.MedicalRecord = patient.MedicalRecord;
            existingPatient.Gender = patient.Gender;
            existingPatient.Phone = patient.Phone;
            existingPatient.Email = patient.Email;
            existingPatient.Address = patient.Address;
            await _context.SaveChangesAsync(cancellationToken);

            return true;
        }

        public async Task<bool> DeletePatientAsync(int id, CancellationToken cancellationToken = default)
        {
            var patient = await GetPatientAsync(id, cancellationToken);
            if (patient == null)
            {
                return false;
            }
            _context.Patients.Remove(patient);
            await _context.SaveChangesAsync(cancellationToken);
            return true;
        }



    }
}