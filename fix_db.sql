IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Labs') AND name = 'Latitude')
    ALTER TABLE Labs ADD Latitude float NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Labs') AND name = 'Longitude')
    ALTER TABLE Labs ADD Longitude float NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Labs') AND name = 'FcmToken')
    ALTER TABLE Labs ADD FcmToken nvarchar(max) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Doctors') AND name = 'FcmToken')
    ALTER TABLE Doctors ADD FcmToken nvarchar(max) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Doctors') AND name = 'ClinicName')
    ALTER TABLE Doctors ADD ClinicName nvarchar(max) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Doctors') AND name = 'ClinicAddress')
    ALTER TABLE Doctors ADD ClinicAddress nvarchar(max) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Doctors') AND name = 'ClinicLatitude')
    ALTER TABLE Doctors ADD ClinicLatitude float NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Doctors') AND name = 'ClinicLongitude')
    ALTER TABLE Doctors ADD ClinicLongitude float NULL;

-- Relatives
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Relatives') AND name = 'FcmToken')
    ALTER TABLE Relatives ADD FcmToken nvarchar(max) NULL;

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Relatives') AND name = 'Email')
    ALTER TABLE Relatives ADD Email nvarchar(max) NULL;

IF NOT EXISTS (SELECT 1 FROM [__EFMigrationsHistory] WHERE MigrationId = '20260609120000_AddMissingColumns')
    INSERT INTO [__EFMigrationsHistory] (MigrationId, ProductVersion)
    VALUES ('20260609120000_AddMissingColumns', '10.0.0');
