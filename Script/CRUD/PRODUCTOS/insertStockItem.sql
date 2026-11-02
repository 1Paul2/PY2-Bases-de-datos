CREATE OR ALTER PROCEDURE SP_InsertStockItem
    @StockItemName NVARCHAR(100),
    @SupplierID INT,
    @LeadTimeDays INT,
    @ColorID INT = NULL,
    @UnitPackageID INT,
    @OuterPackageID INT,
    @QuantityPerOuter INT,
    @Brand NVARCHAR(50) = NULL,
    @Size NVARCHAR(20) = NULL,
    @TaxRate DECIMAL(18, 3),
    @UnitPrice DECIMAL(18, 2),
    @IsChillerStock bit,
    @RecommendedRetailPrice DECIMAL(18, 2) = NULL,
    @TypicalWeightPerUnit DECIMAL(18, 3) = NULL,
    @MarketingComments NVARCHAR(MAX) = NULL,
    @Barcode NVARCHAR(50) = NULL,
    @InternalComments NVARCHAR(MAX) = NULL,
    @BinLocation NVARCHAR(20) = NULL,
    @QuantityOnHand INT = 0,
    @LastStocktakeQuantity INT = NULL,
    @LastCostPrice DECIMAL(18, 2) = NULL,
    @ReorderLevel INT = NULL,
    @TargetStockLevel INT = NULL,
    @StockGroups NVARCHAR(400) = NULL,
    @LastEditedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @LastEditedBy = ISNULL(@LastEditedBy, dbo.FN_EditorWeb());

    IF NOT EXISTS (SELECT 1 FROM Syn_Suppliers WHERE SupplierID = @SupplierID)
        THROW 50020, 'El proveedor indicado no existe.', 1;

    IF EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemName = @StockItemName)
        THROW 50021, 'Ya existe un producto con ese nombre.', 1;

    IF ISNULL(@QuantityOnHand, 0) < 0
        THROW 50022, 'La cantidad disponible no puede ser negativa.', 1;

    IF ISNULL(@LastStocktakeQuantity, 0) < 0 OR ISNULL(@LastCostPrice, 0) < 0
       OR ISNULL(@ReorderLevel, 0) < 0 OR ISNULL(@TargetStockLevel, 0) < 0
        THROW 50025, 'Los valores de inventario no pueden ser negativos.', 1;

    DECLARE @Grupos TABLE (StockGroupID INT PRIMARY KEY);
    INSERT INTO @Grupos (StockGroupID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@StockGroups, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> ''
      AND TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Grupos G WHERE NOT EXISTS (SELECT 1 FROM Syn_StockGroups SG WHERE SG.StockGroupID = G.StockGroupID))
        THROW 50023, 'Uno o más grupos de producto no existen.', 1;

    IF NOT EXISTS (SELECT 1 FROM @Grupos)
        THROW 50024, 'Seleccione al menos un grupo para el producto.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @NewStockItemID INT = NEXT VALUE FOR Sequences.StockItemID;

        INSERT INTO Syn_StockItems
        (
            StockItemID, StockItemName, SupplierID, LeadTimeDays, ColorID,
            UnitPackageID, OuterPackageID, QuantityPerOuter,
            Brand, Size, TaxRate, UnitPrice, IsChillerStock,
            RecommendedRetailPrice, TypicalWeightPerUnit, MarketingComments,
            Barcode, InternalComments, LastEditedBy
        )
        VALUES
        (
            @NewStockItemID, @StockItemName, @SupplierID, @LeadTimeDays, @ColorID,
            @UnitPackageID, @OuterPackageID, @QuantityPerOuter,
            @Brand, @Size, @TaxRate, @UnitPrice, @IsChillerStock,
            @RecommendedRetailPrice, ISNULL(@TypicalWeightPerUnit, 0), @MarketingComments,
            @Barcode, @InternalComments, @LastEditedBy
        );

        INSERT INTO Syn_StockItemHoldings
        (
            StockItemID, QuantityOnHand, BinLocation,
            LastStocktakeQuantity, LastCostPrice,
            ReorderLevel, TargetStockLevel, LastEditedBy
        )
        VALUES
        (
            @NewStockItemID, ISNULL(@QuantityOnHand, 0), ISNULL(@BinLocation, ''),
            ISNULL(@LastStocktakeQuantity, ISNULL(@QuantityOnHand, 0)), ISNULL(@LastCostPrice, @UnitPrice),
            ISNULL(@ReorderLevel, 0), ISNULL(@TargetStockLevel, 0), @LastEditedBy
        );

        INSERT INTO Syn_StockItemStockGroups (StockItemID, StockGroupID, LastEditedBy)
        SELECT @NewStockItemID, StockGroupID, @LastEditedBy
        FROM @Grupos;

        COMMIT TRANSACTION;
        SELECT @NewStockItemID AS NewStockItemID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
