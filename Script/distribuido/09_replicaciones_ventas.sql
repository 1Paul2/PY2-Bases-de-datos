SET NOCOUNT ON;
USE [$(BASE)];
GO

IF N'$(NODO)' = N'corporativo'
BEGIN
    DECLARE @sucursal sysname;
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT s FROM (VALUES (N'sanjose'), (N'limon')) v(s);
    OPEN c;
    FETCH NEXT FROM c INTO @sucursal;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM msdb.dbo.MSdistpublishers WHERE name = @sucursal)
        BEGIN
            EXEC sp_adddistpublisher
                @publisher = @sucursal,
                @distribution_db = N'distribution',
                @working_directory = N'/var/opt/mssql/repldata',
                @security_mode = 0,
                @login = N'wwi_replicacion',
                @password = N'$(REPLICACION_PASSWORD)';
            PRINT CONCAT(@sucursal, ' registrado como publicador');
        END
        ELSE
            PRINT CONCAT(@sucursal, ' ya estaba registrado como publicador');
        FETCH NEXT FROM c INTO @sucursal;
    END
    CLOSE c;
    DEALLOCATE c;
    IF SCHEMA_ID(N'Resumen') IS NULL
        EXEC (N'CREATE SCHEMA Resumen');
END
GO

-- Si esta es diferente a corporativo
IF N'$(NODO)' <> N'corporativo'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.servers WHERE name = N'repl_distributor')
        BEGIN
            EXEC (N'USE master; EXEC sp_adddistributor @distributor = N''corporativo'', @password = N''$(SA_PASSWORD)'';');
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

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'Warehouse.StockItemTransactions') AND type = 5)
    BEGIN
        DECLARE @ccx sysname = (SELECT name FROM sys.indexes WHERE object_id = OBJECT_ID(N'Warehouse.StockItemTransactions') AND type = 5);
        DECLARE @pk sysname = (SELECT name FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID(N'Warehouse.StockItemTransactions') AND type = 'PK');
        EXEC (N'DROP INDEX ' + @ccx + N' ON Warehouse.StockItemTransactions;
                ALTER TABLE Warehouse.StockItemTransactions DROP CONSTRAINT ' + @pk + N';
                ALTER TABLE Warehouse.StockItemTransactions ADD CONSTRAINT ' + @pk + N' PRIMARY KEY CLUSTERED (StockItemTransactionID);');
        PRINT 'StockItemTransactions: indice columnstore reemplazado por la llave primaria agrupada';
    END
END
GO

IF N'$(NODO)' <> N'corporativo'
BEGIN
    BEGIN TRY
        DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';
        EXEC sp_addlogreader_agent @publisher_security_mode = 0, @publisher_login = N'wwi_replicacion', @publisher_password = @clave;
        PRINT 'Agente lector del log creado';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() = 21831
            PRINT 'El agente lector del log ya existia';
        ELSE
            THROW;
    END CATCH
END
GO

-- PASO 6: crea la publicación de la sucursal (PubVentasSJ / PubVentasLI)
IF N'$(NODO)' <> N'corporativo'
BEGIN
    DECLARE @pub sysname = CASE N'$(NODO)' WHEN N'sanjose' THEN N'PubVentasSJ' ELSE N'PubVentasLI' END;

    IF NOT EXISTS (SELECT 1 FROM dbo.syspublications WHERE name = @pub)
    BEGIN
        EXEC sp_addpublication @publication = @pub,
            @description = N'Ventas, compras y movimientos de la sucursal hacia el corporativo',
            @status = N'active', @repl_freq = N'continuous', @independent_agent = N'true',
            @immediate_sync = N'false', @allow_push = N'true', @allow_pull = N'false';
        EXEC sp_grant_publication_access @publication = @pub, @login = N'wwi_replicacion';
        PRINT CONCAT('Publicacion ', @pub, ' creada');
    END
    ELSE
        PRINT CONCAT('La publicacion ', @pub, ' ya existia');

    -- El snapshot crea las tablas Resumen.* en el corporativo y copia los datos que ya existen
    BEGIN TRY
        DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';
        EXEC sp_addpublication_snapshot @publication = @pub,
            @publisher_security_mode = 0, @publisher_login = N'wwi_replicacion', @publisher_password = @clave;
        PRINT CONCAT('Agente de snapshot de ', @pub, ' creado');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        IF ERROR_NUMBER() <> 14101 THROW;
    END CATCH
END
GO

-- PASO 7: agrega las 5 tablas a la publicación; llegan al corporativo como Resumen.<Tabla>_SJ / _LI
-- y solo con las columnas que usan las estadísticas
IF N'$(NODO)' <> N'corporativo'
BEGIN
    DECLARE @pub sysname = CASE N'$(NODO)' WHEN N'sanjose' THEN N'PubVentasSJ' ELSE N'PubVentasLI' END;
    DECLARE @sufijo nvarchar(3) = CASE N'$(NODO)' WHEN N'sanjose' THEN N'_SJ' ELSE N'_LI' END;
    DECLARE @articulo sysname, @esquema sysname, @tabla sysname, @columnas nvarchar(max),
            @destino sysname, @ins nvarchar(255), @upd nvarchar(255), @del nvarchar(255),
            @columna sysname, @operacion nvarchar(4);

    -- Nombre en el corporativo, tabla de origen y columnas que viajan
    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT a, e, t, cols FROM (VALUES
            (N'Facturas',      N'Sales',      N'Invoices',
             N'InvoiceID,CustomerID,SalespersonPersonID,DeliveryMethodID,InvoiceDate'),
            (N'LineasFactura', N'Sales',      N'InvoiceLines',
             N'InvoiceLineID,InvoiceID,StockItemID,Quantity,ExtendedPrice,LineProfit'),
            (N'Compras',       N'Purchasing', N'PurchaseOrders',
             N'PurchaseOrderID,SupplierID,OrderDate'),
            (N'LineasCompra',  N'Purchasing', N'PurchaseOrderLines',
             N'PurchaseOrderLineID,PurchaseOrderID,StockItemID,OrderedOuters,ExpectedUnitPricePerOuter'),
            (N'Movimientos',   N'Warehouse',  N'StockItemTransactions',
             N'StockItemTransactionID,StockItemID,TransactionTypeID,CustomerID,InvoiceID,SupplierID,PurchaseOrderID,TransactionOccurredWhen,Quantity'),
            (N'Existencias',   N'Warehouse',  N'StockItemHoldings',
             N'StockItemID,QuantityOnHand')
        ) v(a, e, t, cols);
    OPEN c;
    FETCH NEXT FROM c INTO @articulo, @esquema, @tabla, @columnas;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.sysarticles a JOIN dbo.syspublications p ON p.pubid = a.pubid
                       WHERE p.name = @pub AND a.name = @articulo)
        BEGIN
            -- Nombres propios para que los procedimientos de SJ y LI no choquen en el corporativo
            SET @destino = @articulo + @sufijo;
            SET @ins = N'CALL sp_MSins_Resumen' + @destino;
            SET @upd = N'SCALL sp_MSupd_Resumen' + @destino;
            SET @del = N'CALL sp_MSdel_Resumen' + @destino;

            EXEC sp_addarticle @publication = @pub, @article = @articulo,
                @source_owner = @esquema, @source_object = @tabla,
                @destination_owner = N'Resumen', @destination_table = @destino,
                @vertical_partition = N'true', @pre_creation_cmd = N'drop',
                @ins_cmd = @ins, @upd_cmd = @upd, @del_cmd = @del;

            -- Las columnas de la lista se agregan; las demás se quitan
            DECLARE cc CURSOR LOCAL FAST_FORWARD FOR
                SELECT name FROM sys.columns WHERE object_id = OBJECT_ID(@esquema + N'.' + @tabla);
            OPEN cc;
            FETCH NEXT FROM cc INTO @columna;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @operacion = CASE WHEN @columna IN (SELECT value FROM STRING_SPLIT(@columnas, N','))
                                      THEN N'add' ELSE N'drop' END;
                EXEC sp_articlecolumn @publication = @pub, @article = @articulo,
                    @column = @columna, @operation = @operacion;
                FETCH NEXT FROM cc INTO @columna;
            END
            CLOSE cc;
            DEALLOCATE cc;
            EXEC sp_articleview @publication = @pub, @article = @articulo, @force_invalidate_snapshot = 1;

            PRINT CONCAT('Articulo ', @esquema, '.', @tabla, ' -> Resumen.', @destino);
        END
        ELSE IF EXISTS (SELECT 1 FROM dbo.sysarticles a JOIN dbo.syspublications p ON p.pubid = a.pubid
                        WHERE p.name = @pub AND a.name = @articulo AND a.pre_creation_cmd <> 1)
        BEGIN
            EXEC sp_changearticle @publication = @pub, @article = @articulo,
                @property = N'pre_creation_cmd', @value = N'drop', @force_invalidate_snapshot = 1;
            EXEC sp_articleview @publication = @pub, @article = @articulo, @force_invalidate_snapshot = 1;
            PRINT CONCAT('Articulo ', @articulo, ' cambiado para usar snapshot');
        END
        ELSE
            PRINT CONCAT('El articulo ', @articulo, ' ya estaba en ', @pub);

        FETCH NEXT FROM c INTO @articulo, @esquema, @tabla, @columnas;
    END
    CLOSE c;
    DEALLOCATE c;
END
GO

-- PASO 8: suscribe al corporativo a la publicación; sin snapshot, porque las tablas Resumen.* ya existen allá
IF N'$(NODO)' <> N'corporativo'
BEGIN
    DECLARE @pub sysname = CASE N'$(NODO)' WHEN N'sanjose' THEN N'PubVentasSJ' ELSE N'PubVentasLI' END;
    DECLARE @clave nvarchar(128) = N'$(REPLICACION_PASSWORD)';

    IF EXISTS (SELECT 1 FROM dbo.syssubscriptions s
               JOIN dbo.sysarticles a ON a.artid = s.artid
               JOIN dbo.syspublications p ON p.pubid = a.pubid
               WHERE p.name = @pub AND s.srvname = N'corporativo' AND (s.sync_type = 2 OR s.nosync_type <> 0))
    BEGIN
        EXEC sp_dropsubscription @publication = @pub, @article = N'all',
            @subscriber = N'corporativo', @destination_db = N'WWI_Corporativo';
        PRINT CONCAT('Suscripcion sin snapshot a ', @pub, ' eliminada para recrearla');
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.syssubscriptions s
                   JOIN dbo.sysarticles a ON a.artid = s.artid
                   JOIN dbo.syspublications p ON p.pubid = a.pubid
                   WHERE p.name = @pub AND s.srvname = N'corporativo')
    BEGIN
        EXEC sp_addsubscription @publication = @pub, @subscriber = N'corporativo',
            @destination_db = N'WWI_Corporativo', @subscription_type = N'Push',
            @sync_type = N'automatic';
        EXEC sp_addpushsubscription_agent @publication = @pub, @subscriber = N'corporativo',
            @subscriber_db = N'WWI_Corporativo',
            @subscriber_security_mode = 0, @subscriber_login = N'wwi_replicacion', @subscriber_password = @clave,
            @frequency_type = 64;
        PRINT CONCAT('Suscripcion del corporativo a ', @pub, ' creada');
    END
    ELSE
        PRINT CONCAT('El corporativo ya estaba suscrito a ', @pub);
END
GO

-- PASO 9 (corporativo, al final, después de las sucursales): genera el snapshot de las publicaciones de ventas.
-- El snapshot que corre solo al crear el agente ocurre antes de que exista la suscripción y no sirve.
-- Los agentes viven en el corporativo (distribuidor); dbo.SP_IniciarAgentesReplicacion (del 08) solo arranca
-- los que no están corriendo.
IF N'$(NODO)' = N'corporativo'
BEGIN
    EXEC dbo.SP_IniciarAgentesReplicacion N'%-PubVentasSJ-[0-9]%';
    EXEC dbo.SP_IniciarAgentesReplicacion N'%-PubVentasLI-[0-9]%';
END
GO

