USE WideWorldImporters;
GO

-- Purchasing
DROP SYNONYM IF EXISTS Syn_Suppliers;
CREATE SYNONYM Syn_Suppliers FOR Purchasing.Suppliers;
DROP SYNONYM IF EXISTS Syn_SupplierCategories;
CREATE SYNONYM Syn_SupplierCategories FOR Purchasing.SupplierCategories;
DROP SYNONYM IF EXISTS Syn_PurchaseOrders;
CREATE SYNONYM Syn_PurchaseOrders FOR Purchasing.PurchaseOrders;
DROP SYNONYM IF EXISTS Syn_PurchaseOrderLines;
CREATE SYNONYM Syn_PurchaseOrderLines FOR Purchasing.PurchaseOrderLines;

-- Application
DROP SYNONYM IF EXISTS Syn_People;
CREATE SYNONYM Syn_People FOR Application.People;
DROP SYNONYM IF EXISTS Syn_DeliveryMethods;
CREATE SYNONYM Syn_DeliveryMethods FOR Application.DeliveryMethods;
DROP SYNONYM IF EXISTS Syn_Cities;
CREATE SYNONYM Syn_Cities FOR Application.Cities;
DROP SYNONYM IF EXISTS Syn_StateProvinces;
CREATE SYNONYM Syn_StateProvinces FOR Application.StateProvinces;
DROP SYNONYM IF EXISTS Syn_Countries;
CREATE SYNONYM Syn_Countries FOR Application.Countries;
DROP SYNONYM IF EXISTS Syn_TransactionTypes;
CREATE SYNONYM Syn_TransactionTypes FOR Application.TransactionTypes;

-- Warehouse
DROP SYNONYM IF EXISTS Syn_StockItems;
CREATE SYNONYM Syn_StockItems FOR Warehouse.StockItems;
DROP SYNONYM IF EXISTS Syn_StockGroups;
CREATE SYNONYM Syn_StockGroups FOR Warehouse.StockGroups;
DROP SYNONYM IF EXISTS Syn_StockItemStockGroups;
CREATE SYNONYM Syn_StockItemStockGroups FOR Warehouse.StockItemStockGroups;
DROP SYNONYM IF EXISTS Syn_StockItemHoldings;
CREATE SYNONYM Syn_StockItemHoldings FOR Warehouse.StockItemHoldings;
DROP SYNONYM IF EXISTS Syn_Colors;
CREATE SYNONYM Syn_Colors FOR Warehouse.Colors;
DROP SYNONYM IF EXISTS Syn_PackageTypes;
CREATE SYNONYM Syn_PackageTypes FOR Warehouse.PackageTypes;
DROP SYNONYM IF EXISTS Syn_StockItemTransactions;
CREATE SYNONYM Syn_StockItemTransactions FOR Warehouse.StockItemTransactions;

-- Sales
DROP SYNONYM IF EXISTS Syn_Invoices;
CREATE SYNONYM Syn_Invoices FOR Sales.Invoices;
DROP SYNONYM IF EXISTS Syn_InvoiceLines;
CREATE SYNONYM Syn_InvoiceLines FOR Sales.InvoiceLines;
DROP SYNONYM IF EXISTS Syn_Customers;
CREATE SYNONYM Syn_Customers FOR Sales.Customers;
DROP SYNONYM IF EXISTS Syn_CustomerCategories;
CREATE SYNONYM Syn_CustomerCategories FOR Sales.CustomerCategories;
DROP SYNONYM IF EXISTS Syn_BuyingGroups;
CREATE SYNONYM Syn_BuyingGroups FOR Sales.BuyingGroups;
GO