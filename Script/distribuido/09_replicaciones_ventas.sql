SET NOCOUNT ON;
USE [$(BASE)];
GO

-- CORPORATIVO: registrar las sucursales como publicadores en el distribuidor
IF N'$(NODO)' = N'corporativo'
BEGIN
    DECLARE @sucursal sysname;
    -- Define la lista que se va a recorrer.
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT s FROM (VALUES (N'sanjose'), (N'limon')) v(s);
    OPEN c;
    -- Lee la c para poder copia el nombre de la variable @sucursal
    FETCH NEXT FROM c INTO @sucursal;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM msdb.dbo.MSdistpublishers WHERE name = @sucursal)
        BEGIN
            EXEC sp_adddistpublisher
                @publisher = @sucursal,
                @distribution_db = N'distribution',
                @working_directory = N'/var/opt/mssql/repldata',
                -- El numero de acceso para la sucursal
                @security_mode = 0,
                @login = N'sa',
                @password = N'$(SA_PASSWORD)';
            PRINT CONCAT(@sucursal, ' registrado como publicador');
        END
        ELSE
            PRINT CONCAT(@sucursal, ' ya estaba registrado como publicador');
        -- Pasamos a la siguiente sucursal
        FETCH NEXT FROM c INTO @sucursal;
    END
    CLOSE c;
    DEALLOCATE c;

    -- Esquema donde llegan las ventas y compras replicadas de las sucursales
    IF SCHEMA_ID(N'Resumen') IS NULL
        EXEC (N'CREATE SCHEMA Resumen');
END
GO

-- Si esta es diferente a corporativo
IF N'$(NODO)' <> N'corporativo'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = N'repl_distributor')
        BEGIN
            EXEC sp_adddistributor @distributor = N'corporativo', @password = N'$(SA_PASSWORD)';
            PRINT 'Distribuidor creado';
        END
    ELSE
        PRINT 'La sucursal ya tenía distribuidor configurado';
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = DB_NAME() AND is_published = 1)
        BEGIN
            EXEC sp_replicationdboption @dbname = N'$(BASE)', @optname = N'publish', @value = N'true';
                PRINT 'Base habilitada para publicar';
        END
    ELSE
        PRINT 'La base ya estaba habilitada para publicar';

END
GO

-- continuara.....
