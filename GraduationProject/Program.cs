var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProjectServices(builder.Configuration);

var app = builder.Build();

// NEW: seed the 5 roles into the database on startup
using (var scope = app.Services.CreateScope())
{
    var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();

    // NEW: the 5 allowed roles
    string[] roles = { "Patient", "Doctor", "Lab", "Relative", "Ambulance" };

    foreach (var role in roles)
    {
        // NEW: only create if it doesn't already exist
        if (!await roleManager.RoleExistsAsync(role))
            await roleManager.CreateAsync(new IdentityRole(role));
    }
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.UseExceptionHandler();

app.Run();