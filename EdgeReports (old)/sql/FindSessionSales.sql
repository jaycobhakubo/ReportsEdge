USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindSessionSalesTotal]    Script Date: 06/22/2011 13:20:11 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FindSessionSalesTotal]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FindSessionSalesTotal]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindSessionSalesTotal]    Script Date: 06/22/2011 13:20:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		GameTech
-- Create date: 06/21/2011
-- Description:	Find totals sales for a given session.
-- =============================================
CREATE FUNCTION [dbo].[FindSessionSalesTotal] 
(
	-- Add the parameters for the function here
	@OperatorID int,
	@GamingDate datetime,
	@SessionNumber int
)
RETURNS money
AS
BEGIN
    -- Validate params
    if(@SessionNumber <= 0) return -1.0;
    
    -- Results table	
    declare @Sales table
	    (
            packageName         NVARCHAR(64),
		    productItemName		NVARCHAR(64),
		    staffIdNbr          int,            -- DE7731
		    staffName           NVARCHAR(64),
		    itemQty			    INT,            -- TC822
		    issueQty			INT,
		    returnQty			INT,
		    skipQty				INT,
		    damageQty			INT,		
		    pricePaid           money,
		    price               money,          -- DE7731
		    gamingDate          datetime,       -- DE7731
		    sessionNbr          int,            -- DE7731
		    merchandise			MONEY,
		    paper				MONEY,          -- original field, represents paper sales made at a register
		    paperSalesFloor 	MONEY,          -- DE7731
		    paperSalesTotal 	MONEY,          -- DE7731
		    electronic			MONEY,
		    credit				MONEY,
		    discount			MONEY,
		    other				MONEY,
		    payouts				MONEY					
            , ProductTypeId     int             -- bjs 5/25/11 Crystal Ball Bingo paper products are non-inventory paper!
	    );

    -- DE7731
    declare @Results table
	    (
            packageName         NVARCHAR(64),
		    productItemName		NVARCHAR(64),
		    gamingDate          datetime,
		    sessionNbr          int,
		    staffIdNbr          int,            
		    staffName           NVARCHAR(64),
		    itemQty			    INT,            -- TC822
		    issueQty			INT,
		    returnQty			INT,
		    skipQty				INT,
		    damageQty			INT,		
		    pricePaid           money,
		    paper				MONEY,          -- original field, represents paper sales made at a register
		    paperSalesFloor 	MONEY,          
		    paperSalesTotal 	MONEY           
            , ProductTypeId     int
	    );
    	
    declare @Results2 table
	    (
            packageName         NVARCHAR(64),
		    productItemName		NVARCHAR(64),
		    gamingDate          datetime,
		    sessionNbr          int,
		    staffIdNbr          int,            
		    staffName           NVARCHAR(64),
		    itemQty			    INT,            -- TC822
		    issueQty			INT,
		    returnQty			INT,
		    skipQty				INT,
		    damageQty			INT,		
		    pricePaid           money,
		    paper				MONEY,          -- original field, represents paper sales made at a register
		    paperSalesFloor 	MONEY,          
		    paperSalesTotal 	MONEY           
            , ProductTypeId     int
	    );
    		
    		
    --		
    -- Insert Merchandise Rows		
    --
    INSERT INTO @Sales
	    (
		    packageName,
		    productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,    
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,
            rdi.ProductItemName, 
		    --NULL,
		    --'',
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731
		    SUM(rd.Quantity * rdi.Qty),
		    SUM(rd.Quantity * rdi.Qty * rdi.Price),
		    0.00, 0.00, 0.00,
		    0.00,
		    0.00,
		    0.00,
		    0.00,
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID = 7
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rd.PackageName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;         -- DE7731

    -- And take out returns
    INSERT INTO @Sales
	    (
	        packageName,
		    productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName, rdi.ProductItemName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(-1 * rd.Quantity * rdi.Qty),
		    SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		    0.00, 0.00, 0.00,
		    0.00,
		    0.00,
		    0.00,
		    0.00,
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID = 7
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rd.PackageName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    --		
    -- Insert Paper Rows		
    --
    INSERT INTO @Sales
	    (
		    packageName,
		    productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName,
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(rd.Quantity * rdi.Qty),--itemQty,
		    0.0,--merchandise,
		    SUM(rd.Quantity * rdi.Qty * rdi.Price), 0.0, 0.0,             --paper,
		    0.0,--electronic,
		    0.0,--credit,
		    0.0,--discount,
		    0.0,--other,
		    0.0--payouts
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)-- Paper
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName,
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,
		    0.0,--merchandise,
		    SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price), 0.0, 0.0, --paper,
		    0.0,--electronic,
		    0.0,--credit,
		    0.0,--discount,
		    0.0,--other,
		    0.0--payouts
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)-- Paper
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    --		
    -- Insert Electronic Rows		
    --
    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName,
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(rd.Quantity * rdi.Qty),--itemQty,
		    0.0,--merchandise,
		    0.0, 0.0, 0.0, --paper,
		    SUM(rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		    0.0,--credit,
		    0.0,--discount,
		    0.0,--other,
		    0.0--payouts
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 

    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    --deviceID,
		    --deviceName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName,
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,
		    0.0,--merchandise,
		    0.0,0.0,0.0, --paper,
		    SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		    0.0,--credit,
		    0.0,--discount,
		    0.0,--other,
		    0.0--payouts
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 

    --		
    -- Insert Credit Rows		
    --
    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(rd.Quantity * rdi.Qty),
		    0.00,
		    0.00, 0.0, 0.0, 
		    0.00,
		    SUM(rd.Quantity * rdi.Qty * rdi.Price),
		    0.00,
		    0.00,
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID BETWEEN 10 AND 13
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(-1 * rd.Quantity * rdi.Qty),
		    0.00,
		    0.00, 0.0, 0.0,
		    0.00,
		    SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		    0.00,
		    0.00,
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID BETWEEN 10 AND 13
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    --		
    -- Insert Discount Rows		
    --
    -- DE7731: treat discounts like sales
    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName, rdi.ProductItemName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(rd.Quantity * rdi.Qty),
		    0.00,
		    0.00, 0.0, 0.0, 
		    0.00,
		    0.00,
		    SUM(rd.Quantity * rdi.Qty * rdi.Price),
		    0.00,
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND (rdi.ProductTypeID = 14
	    OR RDI.ProductItemName LIKE 'Discount%')
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName, rdi.ProductItemName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(-1 * rd.Quantity * rdi.Qty),
		    0.00,
		    0.00, 0.0, 0.0, 
		    0.00,
		    0.00,
		    SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		    0.00,
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND (rdi.ProductTypeID = 14 or rdi.ProductItemName like 'Discount%')
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


    -- FIX DE8075: Restore original discounts as well as new product-name discounts
    --		
    -- Insert Discount Rows		
    --
    INSERT INTO @Sales
	    (
		    packageName, 
		    productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	'Discounts',
            dt.DiscountTypeName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     
		    SUM(rd.Quantity),
		    0.00,
		    0.00, 0.0, 0.0, 
		    0.00,
		    0.00,
		    SUM(rd.Quantity * rd.DiscountAmount),
		    0.00,
		    0.00
		    , 14  -- this is an original discount so make the type identical to the new discounts
    FROM RegisterReceipt rr
	    left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	    left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	    LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	    left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
        and rd.DiscountTypeID IS NOT NULL	
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;

    INSERT INTO @Sales
	    (
	        packageName,
		    productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	'Discounts',
            dt.DiscountTypeName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     
		    SUM(-1 * rd.Quantity),
		    0.00,
		    0.00, 0.0, 0.0, 
		    0.00,
		    0.00,
		    SUM(rd.Quantity * rd.DiscountAmount),       -- TODO should this be multiplied by -1?
		    0.00,
		    0.00
		    , 14  -- this is an original discount so make the type identical to the new discounts
    FROM RegisterReceipt rr
	    left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	    left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	    LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	    left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID)
	    left join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
        and rd.DiscountTypeID IS NOT NULL	
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 
    -- END FIX DE8075


    --		
    -- Insert Other Rows		
    --
    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(rd.Quantity * rdi.Qty),
		    0.00,
		    0.00, 0.0, 0.0, 
		    0.00,
		    0.00,
		    0.00,
		    SUM(rd.Quantity * rdi.Qty * rdi.Price),
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    --AND rdi.ProductTypeID IN (6, 8, 9,14,15, 17)      -- DE7727, DE7729  Show "buy ins"
	    AND rdi.ProductTypeID IN (6, 8, 9, 15, 17)
	    AND RDI.ProductItemName NOT LIKE 'Discount%'
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    packageName,productItemName,
		    staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
		    itemQty,
		    merchandise,
		    paper, paperSalesFloor, paperSalesTotal,
		    electronic,
		    credit,
		    discount,
		    other,
		    payouts
            , ProductTypeId     
	    )
    SELECT	rd.PackageName,rdi.ProductItemName, 
		    rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
		    SUM(-1 * rd.Quantity * rdi.Qty),
		    0.00,
		    0.00, 0.0, 0.0, 
		    0.00,
		    0.00,
		    0.00,
		    SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		    0.00
		    , rdi.ProductTypeID
    FROM RegisterReceipt rr
	    JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	    JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	    LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	    join Staff s on rr.StaffID = s.StaffID
    Where (rr.GamingDate = @GamingDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    --AND rdi.ProductTypeID IN (6, 8, 9, 14, 15, 17)      -- DE7727, DE7729  Show "buy ins"
	    AND rdi.ProductTypeID IN (6, 8, 9, 15, 17)      -- de7731
	    AND RDI.ProductItemName NOT LIKE 'Discount%'    -- de7731
	    And (@SessionNumber = 0 or sp.GamingSession = @SessionNumber)
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rd.PackageName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


    --		
    -- Insert Payout Rows		
    --
    -- TODO: Not currently doing "Payouts"

    -------------------------------------------------------------------------------------------
    -- PAPER SALES
	    -- DE7731
	    -- Finally add Paper Sales, representing sales made from the Floor and not a cash register.
	    -- Identify Paper Sales for each staff member for a date range
	    -- Cloned from spGetIssueData, modify to get issues and returns for a date range
	    -- DE8654: until Inv Center associates products w/ packages, create a pseudo package so
	    --         detail lines are NOT duplicated
	    declare @IssueData table
	    (
		    MasterTransactionID int,
		    IssueNameID int,
		    IssueName nvarchar(60),
		    FromLocationID int,
		    IssuedLocationID int,
		    IssuedLocationName nvarchar(128),
		    InventoryItemID int,
		    SerialNumber nvarchar(60),
		    StartNumber int,
		    EndNumber int,
		    TransDate datetime,
		    SkipCount int,
		    IssuedCount int,
		    ReturnsCount int,
		    DamagedCount int,
		    PlayBackCount int,
		    BonanzaTradeCount int,
		    PricePaid money
		    , GamingDate datetime
		    , StaffID int
		    , GamingSession int
		    , ProductItemName nvarchar(64)
		    , PackageName nvarchar(64)
            , ProductTypeId int
		    );

        with Packages
        (
		    MasterTransactionID,
		    IssueNameID,
		    IssueName,
		    IssuedLocationID,
		    IssuedLocationName,
		    InventoryItemID,
		    SerialNumber,
		    StartNumber,
		    EndNumber,
		    TransDate,
		    SkipCount,
		    IssuedCount,
		    ReturnsCount,
		    DamagedCount,
		    PlayBackCount,
		    BonanzaTradeCount,
		    PricePaid
		    , GamingDate
		    , StaffID
		    , GamingSession
		    , ProductItemName
		    , PackageName
            , ProductTypeId     
        ) as
        (select 
		    MasterTransactionID = CASE ISNULL (ivtMasterTransactionID, 0) WHEN 0 THEN ivtInvTransactionID ELSE ivtMasterTransactionID END,
		    ISNULL(ivtIssueNameID, 0),
		    ISNULL(inIssueName, ''),
		    ilInvLocationID,
		    ilInvLocationName,
		    iiInventoryItemID,
		    iiSerialNo,
		    ivtStartNumber,
		    ivtEndNumber,
		    InvTransaction.ivtGamingDate,	
		    SkipCount = CASE ivtTransactionTypeID WHEN 23 THEN ivdDelta ELSE 0 END,
		    IssuedCount = CASE ivtTransactionTypeID WHEN 25 THEN ivdDelta ELSE 0 END,
		    ReturnsCount = CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END,
		    DamagedCount = CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END,
		    PlayBackCount = CASE ivtTransactionTypeID WHEN 26 THEN ivdDelta ELSE 0 END,
		    BonanzaTradeCount = CASE ivtTransactionTypeID WHEN 24 THEN ivdDelta ELSE 0 END,
		    ivtPrice
		    , ivtGamingDate
		    , ilStaffID
		    , ivtGamingSession
		    , pri.ItemName
		    , 'Floor Sales'
            , pri.ProductTypeID  
	    from InventoryItem 
	    join InvTransaction  on iiInventoryItemID = ivtInventoryItemID
	    join InvTransactionDetail  on ivtInvTransactionID = ivdInvTransactionID
	    join InvLocations  on ivdInvLocationID = ilInvLocationID
	    left join IssueNames  on ivtIssueNameID = inIssueNameID
	    left join ProductItem pri  on pri.ProductItemID = iiProductItemID
	    left join ProductType pt on pri.ProductTypeID = pt.ProductTypeID        -- TC822
	    where 
	    (ilMachineID <> 0 or ilStaffID <> 0)
	    and (ivtGamingDate = @GamingDate)
	    and (ivtGamingSession = @SessionNumber or @SessionNumber = 0)
	    and (pri.OperatorID = @OperatorID)
	    and pt.ProductType like '%paper%'        -- TC822
        )
	    insert @IssueData 
	    (
		    MasterTransactionID,
		    IssueNameID,
		    IssueName,
		    IssuedLocationID,
		    IssuedLocationName,
		    InventoryItemID,
		    SerialNumber,
		    StartNumber,
		    EndNumber,
		    TransDate,
		    SkipCount,
		    IssuedCount,
		    ReturnsCount,
		    DamagedCount,
		    PlayBackCount,
		    BonanzaTradeCount,
		    PricePaid
		    , GamingDate
		    , StaffID
		    , GamingSession
		    , ProductItemName
		    , PackageName
            , ProductTypeId     
		    )
        select 
		    MasterTransactionID,
		    IssueNameID,
		    IssueName,
		    IssuedLocationID,
		    IssuedLocationName,
		    InventoryItemID,
		    SerialNumber,
		    StartNumber,
		    EndNumber,
		    TransDate,
		    SkipCount,
		    IssuedCount,
		    ReturnsCount,
		    DamagedCount,
		    PlayBackCount,
		    BonanzaTradeCount,
		    PricePaid
		    , GamingDate
		    , StaffID
		    , GamingSession
		    , ProductItemName
            , packageName
            , ProductTypeId
        from Packages;
    	

	    -- Set the transaction date in the return to the transaction
	    -- time of the master transaction (issue)
	    -- LJL - Rally DE 6956
	    update @IssueData
	    SET TransDate = it.ivtInvTransactionDate
	    FROM @IssueData id
	    JOIN InvTransaction it ON (id.MasterTransactionID = it.ivtInvTransactionID)
	    WHERE MasterTransactionID = it.ivtInvTransactionID;

	    -- Now calculate "Paper Sales Floor" which represents issues - returns.
        -- TODO: retain skips, damages, etc for FUTURE DEVELOPMENT
        with PAPERSALES(
            itemName, packageName, gdate, transDate, gsession, staffid, name
            , itemQty    -- TC822
            , issues, returns, skips, damages, playbacks, bonanzas, price, productTypeId) as
        ( select 
            ProductItemName, PackageName
          , GamingDate, TransDate, GamingSession, StaffID, IssuedLocationName
          , (IssuedCount + ReturnsCount + DamagedCount + SkipCount)  -- ADD since these qtys are negative
          , IssuedCount, ReturnsCount, SkipCount, DamagedCount, PlayBackCount, BonanzaTradeCount, PricePaid
          , ProductTypeId     
          from @IssueData 
        )
	    insert into @Results( 
	      productItemName, packageName
	    , gamingDate, sessionNbr, staffIdNbr, staffName
	    , itemQty
	    , issueQty, returnQty, skipQty, damageQty
	    , pricePaid
	    , paper, paperSalesFloor, paperSalesTotal, ProductTypeId )
        select 
          p.itemName, p.packageName
        , gdate, gsession, p.staffid
        , s.LastName + ', ' + s.FirstName
        , sum(p.itemQty)    -- TC822
        , sum(p.issues)
        , sum(p.returns)
        , sum(p.skips)
        , sum(p.damages)    
        , p.price
        , 0 -- paper sales at a register
        , sum(p.itemQty * p.price)  -- now that we have issues returns skips and damages, we can use this qty
        , 0 -- total paper sales
        , productTypeId
        from PAPERSALES p
        join Staff s on p.staffid = s.StaffID
        group by p.itemName, p.packageName, p.gdate, p.gsession, p.staffid, s.LastName, s.FirstName,  p.price, p.productTypeId;


        -- Get our "Subtotals"
        insert into @Results2 
        ( 
          productItemName, packageName, gamingDate, sessionNbr, staffIdNbr, staffName
          , itemQty
          , issueQty, returnQty, skipQty, damageQty
          , pricePaid
          , paper, paperSalesFloor, paperSalesTotal, ProductTypeId     
        )
        select 
          productItemName, packageName, gamingDate, sessionNbr, staffIdNbr, staffName
        , (SUM(issueQty) + SUM(returnQty) + SUM(skipQty) + SUM(damageQty))      -- add b/c qty is negative  -- tc822    
        , sum(issueQty)     -- these values for justification internally only
        , sum(returnQty)
        , sum(skipQty)
        , sum(damageQty)    
        , pricePaid
        , SUM(paper)
        , SUM(paperSalesFloor)
        , (SUM(paper) + Abs(SUM(paperSalesFloor) - sum(paper)))
        , ProductTypeId     
        from @Results
        group by 
        productItemName, packageName, gamingDate, sessionNbr, staffIdNbr, staffName, pricePaid, ProductTypeId;

            
    -- Walk thru the @results2 temp table holding papersales and update the #Temp table or insert a new record when missing.
    -- The #Temp does not yet contain floor workers w/o register sales.
    declare @packageName nvarchar(64);
    declare @itemName nvarchar(64);
    declare @staffName nvarchar(64);
    declare @gdate datetime;
    declare @SessionNumberNbr int;
    declare @staffIdNbr int;
    declare @paper money;
    declare @paperSalesFloor money;
    declare @paperSalesTotal money
    declare @itemQty int;
    declare @pricePaid money;
    declare @prodTypeId int;
    set @paper = 0.0;

    declare PAPERCURSOR cursor local fast_forward for 
    select packageName, productItemName, gamingDate, sessionNbr, staffIdNbr, staffName, itemQty, paperSalesFloor, paperSalesTotal, pricePaid, ProductTypeId
    from @Results2;

    open PAPERCURSOR;
    fetch next from PAPERCURSOR into @packageName, @itemName, @gdate, @SessionNumberNbr, @staffIdNbr, @staffName, @itemQty, @paperSalesFloor, @paperSalesTotal, @pricePaid, @prodTypeId;
    while(@@FETCH_STATUS = 0)
    begin
        -- Find recs to insert
        set @paper = 0;     -- DE8731: required for conditions where staff has floor w/o register sales
        
        select @paper = paper
        from @Sales 
        where productItemName = @itemName and gamingDate = @gdate and sessionNbr = @SessionNumberNbr and staffIdNbr = @staffIdNbr;

        --print 'DEBUG: ' + convert(nvarchar(10), @paper) + ' ' + @packageName + ' ' + @itemName + ' ' + convert(nvarchar(10), @gdate) + ' ' + convert(nvarchar(10),@SessionNumberNbr)  + ' ' + @staffName;
        
        if(@paper = 0) -- DE8731: legitimate statement if @paper is properly initialized!
        begin
            insert into @Sales 
            (
              packageName, productItemName, staffIdNbr, staffName
            , gamingDate, sessionNbr
            , price
            , itemQty   -- tc822
            , merchandise
            , paper
            , paperSalesFloor, paperSalesTotal
            , electronic, credit, discount, other, payouts
            , ProductTypeId
            )        
            values
            (
              @packageName, @itemName, @staffIdNbr, @staffName
            , @gdate, @SessionNumberNbr
            , @pricePaid
            , @itemQty
            , 0     -- merchandise data is for register sales only but must NOT be null
            , @paper
            , @paperSalesFloor, @paperSalesTotal
            , 0,0,0,0,0
            , @prodTypeId
            );
        end;
        
        -- Now update the Register Sales records with paper sales data
        update @Sales 
        set paperSalesFloor = @paperSalesFloor, paperSalesTotal = @paperSalesTotal
        where productItemName = @itemName and gamingDate = @gdate and sessionNbr = @SessionNumberNbr and staffIdNbr = @staffIdNbr;
        
        fetch next from PAPERCURSOR into @packageName, @itemName, @gdate, @SessionNumberNbr, @staffIdNbr, @staffName, @itemQty, @paperSalesFloor, @paperSalesTotal, @pricePaid, @prodTypeId;
    end;

    -- cleanup
    close PAPERCURSOR;
    deallocate PAPERCURSOR;
            
    -- DEBUG
    --SELECT	packageName,
    --        productItemName,
    --		staffIdNbr, staffName,
    --		price, gamingDate, sessionNbr,
    --		ProductTypeId,		
    --		SUM(itemQty) AS itemQty,
    --		SUM(merchandise) AS merchandise,
    --		SUM(paper) AS paper,
    --        SUM(paperSalesFloor) as paperSalesFloor,
    --        SUM(paperSalesTotal) as paperSalesTotal,        
    --		SUM(electronic) AS electronic,
    --		SUM(credit) AS credit,
    --		SUM(discount) AS discount,
    --		SUM(other) AS other,
    --		SUM(payouts) AS payouts
    --FROM @Sales
    --GROUP BY packageName, productItemName, staffIdNbr, staffName, price, gamingDate, sessionNbr, ProductTypeId
    --ORDER BY packagename, ProductItemName, gamingDate, staffIdNbr, sessionNbr;

    declare @TotalSales money;
    
    with SALES(merchandise, paperSalesTotal, electronic, credit, discount, other, payouts)
    as
    (
    select	
		    SUM(isnull(merchandise,0)) AS merchandise,
            SUM(isnull(paperSalesTotal,0)) as paperSalesTotal,        
		    SUM(isnull(electronic,0)) AS electronic,
		    SUM(isnull(credit,0)) AS credit,
		    SUM(isnull(discount,0)) AS discount,
		    SUM(isnull(other,0)) AS other,
		    SUM(isnull(payouts,0)) AS payouts		
    from @Sales
    )
    select @TotalSales = merchandise + paperSalesTotal + electronic + credit + discount + other 
    from SALES;

	-- Return the result of the function
	RETURN @TotalSales;

END


GO


