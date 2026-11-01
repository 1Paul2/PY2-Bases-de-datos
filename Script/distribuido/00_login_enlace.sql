SET NOCOUNT ON;

DECLARE @base sysname = N'$(BASE)';
DECLARE @clave nvarchar(128) = N'$(ENLACE_PASSWORD)';
DECLARE @sql nvarchar(max);

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'wwi_enlace')
    SET @sql = N'CREATE LOGIN wwi_enlace WITH PASSWORD = ' + QUOTENAME(@clave, '''') +
               N', DEFAULT_DATABASE = ' + QUOTENAME(@base) + N', CHECK_POLICY = ON, CHECK_EXPIRATION = OFF;';
ELSE
    SET @sql = N'ALTER LOGIN wwi_enlace WITH PASSWORD = ' + QUOTENAME(@clave, '''') +
               N', DEFAULT_DATABASE = ' + QUOTENAME(@base) + N';';
EXEC (@sql);

SET @sql = N'USE ' + QUOTENAME(@base) + N';
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''wwi_enlace'')
    CREATE USER wwi_enlace FOR LOGIN wwi_enlace;
ALTER ROLE db_datareader ADD MEMBER wwi_enlace;
ALTER ROLE db_datawriter ADD MEMBER wwi_enlace;
GRANT EXECUTE TO wwi_enlace;
-- Política de ejemplo de WWI que oculta los clientes a quien no sea db_owner
IF EXISTS (SELECT 1 FROM sys.security_policies WHERE name = N''FilterCustomersBySalesTerritoryRole'' AND is_enabled = 1)
    ALTER SECURITY POLICY Application.FilterCustomersBySalesTerritoryRole WITH (STATE = OFF);';
EXEC (@sql);

PRINT CONCAT('Login wwi_enlace listo en ', @base);
