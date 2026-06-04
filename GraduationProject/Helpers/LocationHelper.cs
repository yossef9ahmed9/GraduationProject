namespace GraduationProject.Helpers
{
    /// <summary>
    /// Shared GPS / location utilities used by AutoEmergencyService and LocationController.
    /// Centralised here so the Haversine formula is never duplicated.
    /// </summary>
    public static class LocationHelper
    {
        /// <summary>
        /// Returns the great-circle distance in kilometres between two GPS coordinates
        /// using the Haversine formula.
        /// </summary>
        public static double HaversineDistance(
            double lat1, double lon1,
            double lat2, double lon2)
        {
            const double R = 6371.0; // Earth radius in km

            var dLat = ToRad(lat2 - lat1);
            var dLon = ToRad(lon2 - lon1);

            var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                    Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2)) *
                    Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return R * c;
        }

        private static double ToRad(double degrees) => degrees * (Math.PI / 180.0);
    }
}
