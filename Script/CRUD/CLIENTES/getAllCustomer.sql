USE WideWorldImporters;
GO
CREATE OR ALTER PROCEDURE SP_GetAllCustomers
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        C.CustomerID,
        C.CustomerName,
        CC.CustomerCategoryName,
        BG.BuyingGroupName,
        P1.FullName AS PrimaryContact,
        P2.FullName AS AlternateContact,
        B.CustomerName AS BillToCustomer,
        DM.DeliveryMethodName,
        City.CityName AS DeliveryCity,
        C.PostalPostalCode,
        C.PhoneNumber,
        C.FaxNumber,
        C.PaymentDays,
        C.WebsiteURL,
        C.DeliveryAddressLine1,
        C.DeliveryAddressLine2,
        C.PostalAddressLine1,
        C.PostalAddressLine2,
        C.DeliveryLocation.Lat AS DeliveryLatitude,
        C.DeliveryLocation.Long AS DeliveryLongitude
    FROM Syn_Customers C
    INNER JOIN Syn_CustomerCategories CC 
        ON C.CustomerCategoryID = CC.CustomerCategoryID
    LEFT JOIN Syn_BuyingGroups BG 
        ON C.BuyingGroupID = BG.BuyingGroupID
    INNER JOIN Syn_People P1 
        ON C.PrimaryContactPersonID = P1.PersonID
    LEFT JOIN Syn_People P2 
        ON C.AlternateContactPersonID = P2.PersonID
    LEFT JOIN Syn_Customers B 
        ON C.BillToCustomerID = B.CustomerID
    INNER JOIN Syn_DeliveryMethods DM 
        ON C.DeliveryMethodID = DM.DeliveryMethodID
    LEFT JOIN Syn_Cities City 
        ON C.DeliveryCityID = City.CityID
    ORDER BY C.CustomerName ASC;
END;
GO