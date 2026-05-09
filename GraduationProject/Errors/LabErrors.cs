namespace GraduationProject.Errors;

public static class LabErrors
{
    public static readonly Error LabNotFound =
        new("Lab.NotFound", "No lab was found with the given ID", StatusCodes.Status404NotFound);

    public static readonly Error DuplicatedLab =
        new("Lab.Duplicated", "Another lab with the same name already exists", StatusCodes.Status409Conflict);
}
