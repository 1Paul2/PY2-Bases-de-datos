-- Configura el corporativo como distribuidor de la replicación (y como su propio publicador).
-- Solo se ejecuta en el corporativo:
--   sqlcmd ... -v SA_PASSWORD=<clave> -i 02_distribuidor.sql
-- Requiere la carpeta /var/opt/mssql/repldata (la crea Docker\levantar.ps1).
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
