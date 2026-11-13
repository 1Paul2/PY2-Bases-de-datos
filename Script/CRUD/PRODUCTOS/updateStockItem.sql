CREATE OR ALTER PROCEDURE SP_UpdateStockItem
    @StockItemID INT,
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
    @QuantityOnHand INT = NULL,
    @LastStocktakeQuantity INT = NULL,
    @LastCostPrice DECIMAL(18, 2) = NULL,
    @ReorderLevel INT = NULL,
    @TargetStockLevel INT = NULL,
    @StockGroups NVARCHAR(400) = NULL,
    @LastEditedBy INT = NULL,
    @Version VARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @LastEditedBy = ISNULL(@LastEditedBy, dbo.FN_EditorWeb());

    IF NOT EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemID = @StockItemID)
        THROW 50001, 'El producto indicado no existe.', 1;

    IF NOT EXISTS (SELECT 1 FROM Syn_Suppliers WHERE SupplierID = @SupplierID)
        THROW 50020, 'El proveedor indicado no existe.', 1;

    IF EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemName = @StockItemName AND StockItemID <> @StockItemID)
        THROW 50021, 'Ya existe otro producto con ese nombre.', 1;

    IF @QuantityOnHand IS NOT NULL AND @QuantityOnHand < 0
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

    IF @StockGroups IS NOT NULL AND NOT EXISTS (SELECT 1 FROM @Grupos)
        THROW 50024, 'Seleccione al menos un grupo para el producto.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @VersionActual VARCHAR(60);
        SELECT @VersionActual = CONCAT(CONVERT(VARCHAR(27), SI.LastEditedWhen, 121), '|', CONVERT(VARCHAR(27), SIH.LastEditedWhen, 121))
        FROM Syn_StockItems SI WITH (UPDLOCK, ROWLOCK)
        LEFT JOIN Syn_StockItemHoldings SIH WITH (UPDLOCK, ROWLOCK) ON SIH.StockItemID = SI.StockItemID
        WHERE SI.StockItemID = @StockItemID;

        IF @Version IS NOT NULL AND @VersionActual <> @Version
            THROW 50026, 'Otro usuario modificó este producto mientras usted lo editaba. Vuelva a abrirlo para ver los cambios.', 1;

        UPDATE Syn_StockItems
        SET StockItemName = @StockItemName,
            SupplierID = @SupplierID,
            LeadTimeDays = @LeadTimeDays,
            ColorID = @ColorID,
            UnitPackageID = @UnitPackageID,
            OuterPackageID = @OuterPackageID,
            QuantityPerOuter = @QuantityPerOuter,
            Brand = @Brand,
            Size = @Size,
            TaxRate = @TaxRate,
            UnitPrice = @UnitPrice,
            IsChillerStock = @IsChillerStock,
            RecommendedRetailPrice = @RecommendedRetailPrice,
            TypicalWeightPerUnit = ISNULL(@TypicalWeightPerUnit, 0),
            MarketingComments = @MarketingComments,
            Barcode = @Barcode,
            InternalComments = @InternalComments,
            LastEditedBy = @LastEditedBy,
            LastEditedWhen = SYSDATETIME()
        WHERE StockItemID = @StockItemID;

        IF EXISTS (SELECT 1 FROM Syn_StockItemHoldings WHERE StockItemID = @StockItemID)
        BEGIN
            UPDATE Syn_StockItemHoldings
            SET BinLocation = ISNULL(@BinLocation, ''),
                QuantityOnHand = ISNULL(@QuantityOnHand, QuantityOnHand),
                LastStocktakeQuantity = ISNULL(@LastStocktakeQuantity, LastStocktakeQuantity),
                LastCostPrice = ISNULL(@LastCostPrice, LastCostPrice),
                ReorderLevel = ISNULL(@ReorderLevel, ReorderLevel),
                TargetStockLevel = ISNULL(@TargetStockLevel, TargetStockLevel),
                LastEditedBy = @LastEditedBy,
                LastEditedWhen = SYSDATETIME()
            WHERE StockItemID = @StockItemID;
        END
        ELSE
        BEGIN
            INSERT INTO Syn_StockItemHoldings (StockItemID, QuantityOnHand, BinLocation, LastStocktakeQuantity, LastCostPrice, ReorderLevel, TargetStockLevel, LastEditedBy)
            VALUES (@StockItemID, ISNULL(@QuantityOnHand, 0), ISNULL(@BinLocation, ''),
                    ISNULL(@LastStocktakeQuantity, ISNULL(@QuantityOnHand, 0)), ISNULL(@LastCostPrice, @UnitPrice),
                    ISNULL(@ReorderLevel, 0), ISNULL(@TargetStockLevel, 0), @LastEditedBy);
        END

        IF @StockGroups IS NOT NULL
        BEGIN
            DELETE FROM Syn_StockItemStockGroups
            WHERE StockItemID = @StockItemID
              AND StockGroupID NOT IN (SELECT StockGroupID FROM @Grupos);

            INSERT INTO Syn_StockItemStockGroups (StockItemID, StockGroupID, LastEditedBy)
            SELECT @StockItemID, G.StockGroupID, @LastEditedBy
            FROM @Grupos G
            WHERE NOT EXISTS (SELECT 1 FROM Syn_StockItemStockGroups X
                              WHERE X.StockItemID = @StockItemID AND X.StockGroupID = G.StockGroupID);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
