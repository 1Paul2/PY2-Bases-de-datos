SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = N'repl_distributor')
BEGIN
    DECLARE @servidor sysname = @@SERVERNAME;
    EXEC sp_adddistributor @distributor = @servidor, @password = N'$(SA_PASSWORD)';
    EXEC sp_adddistributiondb @database = N'distribution', @security_mode = 1;
    PRINT 'Distribuidor creado';
END
ELSE
    PRINT 'El distribuidor ya existe';

IF NOT EXISTS (SELECT 1 FROM distribution.sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
BEGIN
    EXEC (N'USE distribution; CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''$(SA_PASSWORD)'';');
    PRINT 'Master key creada en distribution';
END

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.MSdistpublishers WHERE name = @@SERVERNAME)
BEGIN
    DECLARE @publicador sysname = @@SERVERNAME;
    EXEC sp_adddistpublisher
        @publisher = @publicador,
        @distribution_db = N'distribution',
        @working_directory = N'/var/opt/mssql/repldata',
        @security_mode = 1;
    PRINT 'Corporativo registrado como publicador';
END
ELSE
    PRINT 'El publicador ya está registrado';
