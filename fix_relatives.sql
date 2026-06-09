-- Add missing Email column to Relatives table
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Relatives') AND name = 'Email')
    ALTER TABLE Relatives ADD Email nvarchar(450) NULL;

-- Add index on Email if not exists  
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('Relatives') AND name = 'IX_Relatives_Email')
    CREATE INDEX IX_Relatives_Email ON Relatives(Email);
