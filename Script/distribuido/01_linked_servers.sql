SET NOCOUNT ON;

DECLARE @nodo sysname = N'$(NODO)';
DECLARE @clave nvarchar(128) = N'$(ENLACE_PASSWORD)';
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
        @rmtuser = N'wwi_enlace',
        @rmtpassword = @clave;

    EXEC sp_serveroption @nombre, 'rpc', 'true';
    EXEC sp_serveroption @nombre, 'rpc out', 'true';
    EXEC sp_serveroption @nombre, 'remote proc transaction promotion', 'false';
    -- bloquear consulta si el server no responde en 5 s y aborta si la consulta tarda más de 30 s
    EXEC sp_serveroption @nombre, 'connect timeout', '5';
    EXEC sp_serveroption @nombre, 'query timeout', '30';

    PRINT CONCAT('Linked server ', @nombre, ' -> ', @servidor, ' creado');
    FETCH NEXT FROM c INTO @nombre, @servidor;
END
CLOSE c;
DEALLOCATE c;
