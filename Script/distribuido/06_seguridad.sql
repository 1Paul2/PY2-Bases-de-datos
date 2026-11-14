SET NOCOUNT ON;
-- Trabajar sobre la base del nodo
USE [$(BASE)];
GO

-- Se crea el esquema seguridad solo si no existe
IF NOT EXISTS (
    SELECT 1 FROM sys.schemas
    WHERE name = N'Seguridad')

EXEC (N'CREATE SCHEMA Seguridad');
GO


-- Llaves para cifrar las contraseñas. La master key y el certificado son propios de cada nodo,
-- pero la llave simétrica se crea con el mismo KEY_SOURCE e IDENTITY_VALUE en los tres:
-- así es la misma llave, y una contraseña cifrada en el corporativo se descifra en cualquier sucursal.
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'$(SA_PASSWORD)';
END
GO

-- Se crea el certificado usuario 
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = N'CertUsuarios')
BEGIN
    CREATE CERTIFICATE CertUsuarios WITH SUBJECT = N'Contrasenas de Seguridad.Usuarios';
END
GO

-- Se crea la llave usuario aqui 
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = N'LlaveUsuarios')
BEGIN
    CREATE SYMMETRIC KEY LlaveUsuarios
        WITH ALGORITHM = AES_256,
             KEY_SOURCE = N'$(LLAVE_ORIGEN)',
             IDENTITY_VALUE = N'$(LLAVE_IDENTIDAD)'
        ENCRYPTION BY CERTIFICATE CertUsuarios;
END
GO

-- Maestra en el corporativo; las sucursales reciben la copia por replicación transaccional.
-- Un administrador pertenece a una sucursal; el corporativo no.
IF OBJECT_ID(N'Seguridad.Usuarios') IS NULL
BEGIN
    CREATE TABLE Seguridad.Usuarios (
        IdUser int IDENTITY(1, 1) NOT NULL CONSTRAINT PK_Usuarios PRIMARY KEY,
        Username nvarchar(50) NOT NULL CONSTRAINT UQ_Usuarios_Username UNIQUE,
        Password varbinary(256) NOT NULL,
        FullName nvarchar(100) NOT NULL,
        Active bit NOT NULL CONSTRAINT DF_Usuarios_Active DEFAULT 1,
        Rol nvarchar(20) NOT NULL CONSTRAINT CK_Usuarios_Rol CHECK (Rol IN (N'Administrador', N'Corporativo')),
        Email nvarchar(256) NULL,
        HireDate date NOT NULL CONSTRAINT DF_Usuarios_HireDate DEFAULT CAST(SYSDATETIME() AS date),
        Sucursal char(2) NULL,
        CONSTRAINT CK_Usuarios_Sucursal CHECK (
            (Rol = N'Administrador' AND Sucursal IN ('SJ', 'LI'))
            OR (Rol = N'Corporativo' AND Sucursal IS NULL))
    );
    PRINT 'Tabla Seguridad.Usuarios creada';
END
GO

-- La contraseña se cifra con el nombre de usuario como autenticador:
-- si alguien copia la contraseña cifrada de un usuario a otro, ya no se puede descifrar.
CREATE OR ALTER PROCEDURE Seguridad.SP_CrearUsuario
    @Username NVARCHAR(50),
    @Password NVARCHAR(128),
    @FullName NVARCHAR(100),
    @Rol NVARCHAR(20),
    @Sucursal CHAR(2) = NULL,
    @Email NVARCHAR(256) = NULL,
    @HireDate DATE = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF OBJECT_ID(N'Sales.CustomersSensible') IS NULL
        THROW 50090, 'Los usuarios solo se crean en el corporativo.', 1;

    IF LEN(@Password) < 8
        THROW 50040, 'La contraseña debe tener al menos 8 caracteres.', 1;

    IF @Rol NOT IN (N'Administrador', N'Corporativo')
        THROW 50041, 'El rol debe ser Administrador o Corporativo.', 1;

    IF (@Rol = N'Administrador' AND ISNULL(@Sucursal, '') NOT IN ('SJ', 'LI'))
       OR (@Rol = N'Corporativo' AND @Sucursal IS NOT NULL)
        THROW 50042, 'Un administrador debe tener sucursal (SJ o LI) y un usuario corporativo no lleva sucursal.', 1;

    IF EXISTS (SELECT 1 FROM Seguridad.Usuarios WHERE Username = @Username)
        THROW 50043, 'Ya existe un usuario con ese nombre.', 1;

    OPEN SYMMETRIC KEY LlaveUsuarios DECRYPTION BY CERTIFICATE CertUsuarios;

    INSERT INTO Seguridad.Usuarios (Username, Password, FullName, Rol, Sucursal, Email, HireDate)
    VALUES (
        @Username,
        EncryptByKey(Key_GUID(N'LlaveUsuarios'), @Password, 1, CONVERT(VARBINARY(100), @Username)),
        @FullName,
        @Rol,
        @Sucursal,
        @Email,
        ISNULL(@HireDate, CAST(SYSDATETIME() AS DATE))
    );

    CLOSE SYMMETRIC KEY LlaveUsuarios;

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS IdUser;
END;
GO

-- Compara la contraseña dentro de SQL Server: nunca la devuelve, solo los datos de la sesión.
-- Usuario inexistente y contraseña incorrecta dan el mismo mensaje, para no revelar qué usuarios existen.
CREATE OR ALTER PROCEDURE Seguridad.SP_IniciarSesion
    @Username NVARCHAR(50),
    @Password NVARCHAR(128)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdUser INT, @Active BIT, @Guardada NVARCHAR(128);

    OPEN SYMMETRIC KEY LlaveUsuarios DECRYPTION BY CERTIFICATE CertUsuarios;

    SELECT @IdUser = IdUser,
           @Active = Active,
           @Guardada = CONVERT(NVARCHAR(128), DecryptByKey(Password, 1, CONVERT(VARBINARY(100), Username)))
    FROM Seguridad.Usuarios
    WHERE Username = @Username;

    CLOSE SYMMETRIC KEY LlaveUsuarios;

    IF @IdUser IS NULL OR @Guardada IS NULL OR @Guardada <> @Password COLLATE Latin1_General_BIN2
        THROW 50044, 'Usuario o contraseña incorrectos.', 1;

    IF @Active = 0
        THROW 50045, 'El usuario está inactivo.', 1;

    SELECT IdUser, Username, FullName, Rol, Sucursal
    FROM Seguridad.Usuarios
    WHERE IdUser = @IdUser;
END;
GO

-- Usuarios de ejemplo para la revisión: un administrador por sucursal y uno corporativo.
-- Solo se crean en el corporativo; las sucursales los reciben por replicación.
IF N'$(NODO)' = N'corporativo'
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Seguridad.Usuarios WHERE Username = N'admin.sj')
        EXEC Seguridad.SP_CrearUsuario N'admin.sj', N'$(USUARIOS_PASSWORD)', N'Administrador San José',
             N'Administrador', 'SJ', N'admin.sj@wideworldimporters.com';

    IF NOT EXISTS (SELECT 1 FROM Seguridad.Usuarios WHERE Username = N'admin.li')
        EXEC Seguridad.SP_CrearUsuario N'admin.li', N'$(USUARIOS_PASSWORD)', N'Administrador Limón',
             N'Administrador', 'LI', N'admin.li@wideworldimporters.com';

    IF NOT EXISTS (SELECT 1 FROM Seguridad.Usuarios WHERE Username = N'corporativo')
        EXEC Seguridad.SP_CrearUsuario N'corporativo', N'$(USUARIOS_PASSWORD)', N'Usuario Corporativo',
             N'Corporativo', NULL, N'corporativo@wideworldimporters.com';

    DECLARE @total int = (SELECT COUNT(*) FROM Seguridad.Usuarios);
END
GO
