USE WideWorldImporters;
GO

/*
  Actualiza el producto, su inventario (cantidad y ubicación) y sus grupos.
  Si @StockGroups viene NULL los grupos no se tocan; si viene con IDs se reemplazan.
  Si @QuantityOnHand viene NULL la cantidad disponible no se cambia.
*/
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
    @BinLocation NVARCHAR(20) = NULL,
    @QuantityOnHand INT = NULL,
    @StockGroups NVARCHAR(400) = NULL,
    @LastEditedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Quién hizo el cambio lo decide la base: si no viene, se usa la persona PagWeb (usuario de la página web)
    SET @LastEditedBy = ISNULL(@LastEditedBy, dbo.FN_EditorWeb());

    IF NOT EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemID = @StockItemID)
        THROW 50001, 'El producto indicado no existe.', 1;

    IF NOT EXISTS (SELECT 1 FROM Syn_Suppliers WHERE SupplierID = @SupplierID)
        THROW 50020, 'El proveedor indicado no existe.', 1;

    IF EXISTS (SELECT 1 FROM Syn_StockItems WHERE StockItemName = @StockItemName AND StockItemID <> @StockItemID)
        THROW 50021, 'Ya existe otro producto con ese nombre.', 1;

    IF @QuantityOnHand IS NOT NULL AND @QuantityOnHand < 0
        THROW 50022, 'La cantidad disponible no puede ser negativa.', 1;

    DECLARE @Grupos TABLE (StockGroupID INT PRIMARY KEY);
    INSERT INTO @Grupos (StockGroupID)
    SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
    FROM STRING_SPLIT(ISNULL(@StockGroups, ''), ',')
    WHERE LTRIM(RTRIM(value)) <> ''   -- '' se convertiría en 0
      AND TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Grupos G WHERE NOT EXISTS (SELECT 1 FROM Syn_StockGroups SG WHERE SG.StockGroupID = G.StockGroupID))
        THROW 50023, 'Uno o más grupos de producto no existen.', 1;

    IF @StockGroups IS NOT NULL AND NOT EXISTS (SELECT 1 FROM @Grupos)
        THROW 50024, 'Seleccione al menos un grupo para el producto.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

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
            LastEditedBy = @LastEditedBy
        WHERE StockItemID = @StockItemID;

        IF EXISTS (SELECT 1 FROM Syn_StockItemHoldings WHERE StockItemID = @StockItemID)
        BEGIN
            UPDATE Syn_StockItemHoldings
            SET BinLocation = ISNULL(@BinLocation, ''),
                QuantityOnHand = ISNULL(@QuantityOnHand, QuantityOnHand),
                LastEditedBy = @LastEditedBy
            WHERE StockItemID = @StockItemID;
        END
        ELSE
        BEGIN
            INSERT INTO Syn_StockItemHoldings (StockItemID, QuantityOnHand, BinLocation, LastStocktakeQuantity, LastCostPrice, ReorderLevel, TargetStockLevel, LastEditedBy)
            VALUES (@StockItemID, ISNULL(@QuantityOnHand, 0), ISNULL(@BinLocation, ''), ISNULL(@QuantityOnHand, 0), @UnitPrice, 0, 0, @LastEditedBy);
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
