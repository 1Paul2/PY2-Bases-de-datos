-- Linked servers entre los nodos.
-- Se ejecuta con sqlcmd en cada nodo, pasando el nodo y la clave de sa:
--   sqlcmd ... -v NODO=corporativo SA_PASSWORD=<clave> -i 01_linked_servers.sql
-- En el corporativo crea LS_SANJOSE y LS_LIMON; en cada sucursal crea LS_CORPORATIVO.
SET NOCOUNT ON;

DECLARE @nodo sysname = N'$(NODO)';
DECLARE @clave nvarchar(128) = N'$(SA_PASSWORD)';
DECLARE @destinos TABLE (nombre sysname, servidor sysname);

IF @nodo = N'corporativo'
    INSERT INTO @destinos VALUES (N'LS_SANJOSE', N'sanjose'), (N'LS_LIMON', N'limon');
ELSE
    INSERT INTO @destinos VALUES (N'LS_CORPORATIVO', N'corporativo');

DECLARE @nombre sysname, @servidor sysname;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT nombre, servidor FROM @destinos;
OPEN c;
FETCH NEXT FROM c INTO @nombre, @servidor;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM sys.servers WHERE name = @nombre)
        EXEC sp_dropserver @server = @nombre, @droplogins = 'droplogins';

    EXEC sp_addlinkedserver
        @server = @nombre,
        @srvproduct = N'',
        @provider = N'MSOLEDBSQL',
        @datasrc = @servidor,
        @provstr = N'TrustServerCertificate=yes';

    EXEC sp_addlinkedsrvlogin
        @rmtsrvname = @nombre,
        @useself = 'FALSE',
        @locallogin = NULL,
        @rmtuser = N'sa',
        @rmtpassword = @clave;

    -- RPC para ejecutar procedimientos remotos; sin promoción a transacción distribuida (no hay MSDTC)
    EXEC sp_serveroption @nombre, 'rpc', 'true';
    EXEC sp_serveroption @nombre, 'rpc out', 'true';
    EXEC sp_serveroption @nombre, 'remote proc transaction promotion', 'false';

    PRINT CONCAT('Linked server ', @nombre, ' -> ', @servidor, ' creado');
    FETCH NEXT FROM c INTO @nombre, @servidor;
END
CLOSE c;
DEALLOCATE c;
