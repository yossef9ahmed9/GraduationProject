-- LocationSource for Ambulances
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Ambulances') AND name = 'LocationSource')
    ALTER TABLE Ambulances ADD LocationSource nvarchar(20) NOT NULL DEFAULT 'Unknown';

-- Mark migration as applied
IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE MigrationId = '20260609130000_AddAmbulanceLocationSource')
    INSERT INTO [__EFMigrationsHistory] (MigrationId, ProductVersion)
    VALUES ('20260609130000_AddAmbulanceLocationSource', '10.0.0');
