

namespace GraduationProject.Errors;

public static class SensorErrors
{
    public static readonly Error SensorNotFound =
        new("Sensor.NotFound", "No Sensor was found with the given ID", StatusCodes.Status404NotFound);

}