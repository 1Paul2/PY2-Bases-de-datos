SET NOCOUNT ON;
USE [$(BASE)];
GO

-- SUCURSALES
IF N'$(NODO)' <> N'corporativo'
BEGIN
    DECLARE @tabla nvarchar(256), @llave sysname, @cols nvarchar(max), @sql nvarchar(max), @n int;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT t, k FROM (VALUES (N'Application.People', N'PersonID'), (N'Purchasing.Suppliers', N'SupplierID'),
                                 (N'Sales.Customers', N'CustomerID')) v(t, k);
    OPEN c;
    FETCH NEXT FROM c INTO @tabla, @llave;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @cols = (SELECT STRING_AGG(CAST(QUOTENAME(name) AS nvarchar(max)), N', ') WITHIN GROUP (ORDER BY column_id)
                     FROM sys.columns WHERE object_id = OBJECT_ID(@tabla) AND is_computed = 0);
        SET @sql = N'INSERT INTO ' + @tabla + N' (' + @cols + N') SELECT ' + @cols +
                   N' FROM LS_CORPORATIVO.WWI_Corporativo.' + @tabla + N' c
                     WHERE NOT EXISTS (SELECT 1 FROM ' + @tabla + N' s WHERE s.' + @llave + N' = c.' + @llave + N');
                   SET @n = @@ROWCOUNT;';
        EXEC sp_executesql @sql, N'@n int OUTPUT', @n OUTPUT;
        IF @n > 0 PRINT CONCAT(@tabla, ': ', @n, ' filas copiadas del corporativo');
        FETCH NEXT FROM c INTO @tabla, @llave;
    END
    CLOSE c;
    DEALLOCATE c;
    PRINT 'Datos alineados con el corporativo';

    DECLARE @fk sysname = (SELECT fk.name FROM sys.foreign_keys fk
                           WHERE fk.parent_object_id = OBJECT_ID(N'Warehouse.StockItemHoldings')
                             AND fk.referenced_object_id = OBJECT_ID(N'Warehouse.StockItems')
                             AND fk.delete_referential_action = 0);
    IF @fk IS NOT NULL
    BEGIN
        EXEC (N'ALTER TABLE Warehouse.StockItemHoldings DROP CONSTRAINT ' + @fk + N';
                ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT ' + @fk + N'
                    FOREIGN KEY (StockItemID) REFERENCES Warehouse.StockItems (StockItemID) ON DELETE CASCADE;');
        PRINT 'Existencias: borrado en cascada al borrar el producto';
    END
    SET NOEXEC ON;
END
GO

--Corporativo

-- Arranca los agentes de replicación (jobs del Agent) cuyo nombre cumple el patrón y que no estén corriendo.
-- Si un agente ya corre por su horario, sp_start_job y sp_startpublication_snapshot fallan con un error
-- del Agent que TRY/CATCH no atrapa, y levantar se detiene.
CREATE OR ALTER PROCEDURE dbo.SP_IniciarAgentesReplicacion
    @Patron NVARCHAR(256),
    @Excluir NVARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @job sysname;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT j.name FROM msdb.dbo.sysjobs j
        WHERE j.name LIKE @Patron
          AND (@Excluir IS NULL OR j.name NOT LIKE @Excluir)
          AND NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobactivity a
                          WHERE a.job_id = j.job_id
                            AND a.session_id = (SELECT MAX(session_id) FROM msdb.dbo.syssessions)
                            AND a.start_execution_date IS NOT NULL AND a.stop_execution_date IS NULL);
    OPEN c;
    FETCH NEXT FROM c INTO @job;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC msdb.dbo.sp_start_job @job_name = @job;
        PRINT CONCAT('Agente iniciado: ', @job);
        FETCH NEXT FROM c INTO @job;
    END
    CLOSE c;
    DEALLOCATE c;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = DB_NAME() AND is_merge_published = 1)
    EXEC sp_replicationdboption @dbname = N'$(BASE)', @optname = N'merge publish', @value = N'true';
GO

IF NOT EXISTS (SELECT 1 FROM dbo.sysmergepublications WHERE name = N'PubCatalogo')
BEGIN
    DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';
    EXEC sp_addmergepublication @publication = N'PubCatalogo',
        @description = N'Catalogo de productos: se modifica en cualquier nodo',
        @retention = 14, @allow_push = N'true', @allow_pull = N'false',
        @conflict_logging = N'both', @publication_compatibility_level = N'90RTM';
    EXEC sp_addpublication_snapshot @publication = N'PubCatalogo',
        @publisher_security_mode = 0, @publisher_login = N'wwi_replicacion', @publisher_password = @clave;
    EXEC sp_grant_publication_access @publication = N'PubCatalogo', @login = N'wwi_replicacion';

    EXEC sp_addmergearticle @publication = N'PubCatalogo', @article = N'Colors',
        @source_owner = N'Warehouse', @source_object = N'Colors', @destination_owner = N'Warehouse';
    EXEC sp_addmergearticle @publication = N'PubCatalogo', @article = N'PackageTypes',
        @source_owner = N'Warehouse', @source_object = N'PackageTypes', @destination_owner = N'Warehouse';
    EXEC sp_addmergearticle @publication = N'PubCatalogo', @article = N'StockGroups',
        @source_owner = N'Warehouse', @source_object = N'StockGroups', @destination_owner = N'Warehouse';
    EXEC sp_addmergearticle @publication = N'PubCatalogo', @article = N'StockItems',
        @source_owner = N'Warehouse', @source_object = N'StockItems', @destination_owner = N'Warehouse',
        @article_resolver = N'Microsoft SQL Server DATETIME (Later Wins) Conflict Resolver',
        @resolver_info = N'LastEditedWhen';
    EXEC sp_addmergearticle @publication = N'PubCatalogo', @article = N'StockItemStockGroups',
        @source_owner = N'Warehouse', @source_object = N'StockItemStockGroups', @destination_owner = N'Warehouse';
    PRINT 'Publicacion merge PubCatalogo creada';
END
GO

IF (SELECT snapshot_ready FROM dbo.sysmergepublications WHERE name = N'PubCatalogo') = 0
BEGIN
    EXEC dbo.SP_IniciarAgentesReplicacion N'%-$(BASE)-PubCatalogo-[0-9]%';
    DECLARE @espera int = 0;
    WHILE (SELECT snapshot_ready FROM dbo.sysmergepublications WHERE name = N'PubCatalogo') = 0 AND @espera < 60
    BEGIN
        WAITFOR DELAY '00:00:05';
        SET @espera += 1;
    END
    IF (SELECT snapshot_ready FROM dbo.sysmergepublications WHERE name = N'PubCatalogo') = 0
        THROW 50100, 'El snapshot de PubCatalogo no termino en 5 minutos.', 1;
    PRINT 'Snapshot de PubCatalogo listo';
END
GO

DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)', @sub sysname, @db sysname;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT s, d FROM (VALUES (N'sanjose', N'WWI_SanJose'), (N'limon', N'WWI_Limon')) v(s, d);
OPEN c;
FETCH NEXT FROM c INTO @sub, @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.sysmergesubscriptions WHERE subscriber_server = @sub AND db_name = @db)
    BEGIN
        EXEC sp_addmergesubscription @publication = N'PubCatalogo', @subscriber = @sub, @subscriber_db = @db,
            @subscription_type = N'push', @sync_type = N'none';
        EXEC sp_addmergepushsubscription_agent @publication = N'PubCatalogo', @subscriber = @sub, @subscriber_db = @db,
            @subscriber_security_mode = 0, @subscriber_login = N'wwi_replicacion', @subscriber_password = @clave,
            @publisher_security_mode = 0, @publisher_login = N'wwi_replicacion', @publisher_password = @clave,
            @frequency_type = 4, @frequency_interval = 1, @frequency_subday = 4, @frequency_subday_interval = 1;
        PRINT CONCAT('Suscripcion merge de ', @sub, ' creada');
    END
    FETCH NEXT FROM c INTO @sub, @db;
END
CLOSE c;
DEALLOCATE c;
GO

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = DB_NAME() AND is_published = 1)
    EXEC sp_replicationdboption @dbname = N'$(BASE)', @optname = N'publish', @value = N'true';
GO

DECLARE @lectores int;
EXEC sp_executesql N'SELECT @n = COUNT(*) FROM distribution.dbo.MSlogreader_agents WHERE publisher_db = DB_NAME();',
    N'@n int OUTPUT', @lectores OUTPUT;
IF @lectores = 0
BEGIN
    DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';
    EXEC sp_addlogreader_agent @publisher_security_mode = 0, @publisher_login = N'wwi_replicacion', @publisher_password = @clave;
    PRINT 'Agente lector del log creado';
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.syspublications WHERE name = N'PubDatos')
BEGIN
    EXEC sp_addpublication @publication = N'PubDatos',
        @description = N'Fragmento publico de clientes, proveedores y personas',
        @status = N'active', @repl_freq = N'continuous', @independent_agent = N'true',
        @immediate_sync = N'false', @allow_push = N'true', @allow_pull = N'false';
    EXEC sp_grant_publication_access @publication = N'PubDatos', @login = N'wwi_replicacion';
    EXEC sp_addarticle @publication = N'PubDatos', @article = N'People',
        @source_owner = N'Application', @source_object = N'People', @pre_creation_cmd = N'none';
    EXEC sp_addarticle @publication = N'PubDatos', @article = N'Suppliers',
        @source_owner = N'Purchasing', @source_object = N'Suppliers', @pre_creation_cmd = N'none';
    EXEC sp_addarticle @publication = N'PubDatos', @article = N'Customers',
        @source_owner = N'Sales', @source_object = N'Customers', @pre_creation_cmd = N'none';
    PRINT 'Publicacion transaccional PubDatos creada';
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.syspublications WHERE name = N'PubUsuarios')
BEGIN
    DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';
    EXEC sp_addpublication @publication = N'PubUsuarios',
        @description = N'Usuarios del sistema con la contrasena cifrada',
        @status = N'active', @repl_freq = N'continuous', @independent_agent = N'true',
        @immediate_sync = N'true', @allow_push = N'true', @allow_pull = N'false';
    EXEC sp_addpublication_snapshot @publication = N'PubUsuarios',
        @publisher_security_mode = 0, @publisher_login = N'wwi_replicacion', @publisher_password = @clave;
    EXEC sp_grant_publication_access @publication = N'PubUsuarios', @login = N'wwi_replicacion';
    EXEC sp_addarticle @publication = N'PubUsuarios', @article = N'Usuarios',
        @source_owner = N'Seguridad', @source_object = N'Usuarios', @pre_creation_cmd = N'drop';
    PRINT 'Publicacion transaccional PubUsuarios creada';
END
GO

DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)', @pub sysname, @tipo nvarchar(40), @sub sysname, @db sysname;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT p, t, s, d FROM (VALUES (N'PubDatos', N'replication support only'), (N'PubUsuarios', N'automatic')) pubs(p, t)
    CROSS JOIN (VALUES (N'sanjose', N'WWI_SanJose'), (N'limon', N'WWI_Limon')) subs(s, d);
OPEN c;
FETCH NEXT FROM c INTO @pub, @tipo, @sub, @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.syssubscriptions s JOIN dbo.sysarticles a ON a.artid = s.artid
                   JOIN dbo.syspublications p ON p.pubid = a.pubid
                   WHERE p.name = @pub AND s.srvname = @sub AND s.dest_db = @db)
    BEGIN
        EXEC sp_addsubscription @publication = @pub, @subscriber = @sub, @destination_db = @db,
            @subscription_type = N'Push', @sync_type = @tipo;
        EXEC sp_addpushsubscription_agent @publication = @pub, @subscriber = @sub, @subscriber_db = @db,
            @subscriber_security_mode = 0, @subscriber_login = N'wwi_replicacion', @subscriber_password = @clave,
            @frequency_type = 64;
        PRINT CONCAT('Suscripcion de ', @sub, ' a ', @pub, ' creada');
    END
    FETCH NEXT FROM c INTO @pub, @tipo, @sub, @db;
END
CLOSE c;
DEALLOCATE c;
GO

-- Snapshot de usuarios (las sucursales lo necesitan para su primera copia) y primera sincronización merge
EXEC dbo.SP_IniciarAgentesReplicacion N'%-$(BASE)-PubUsuarios-[0-9]%';
EXEC dbo.SP_IniciarAgentesReplicacion N'%-$(BASE)-PubCatalogo-%', N'%-PubCatalogo-[0-9]%';
PRINT 'Replicacion configurada en el corporativo';
GO

SET NOEXEC OFF;
GO
