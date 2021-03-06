USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptGameAnalysis]    Script Date: 06/22/2011 12:34:23 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptGameAnalysis]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptGameAnalysis]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptGameAnalysis]    Script Date: 06/22/2011 12:34:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptGameAnalysis] 
(
-- =============================================
-- Author:		Barry J. Silver
-- Description:	Show performance and profitability for each game
--
-- BJS - 05/27/2011  US1849 new report
-- BJS 06/23/2011	DE8692 missing floor sales
--
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session 	AS INT
)
as
begin
    set nocount on;

-- cloned from FindSessionSales
-- modified to return a table not a scalar

-- Shape expected by the .rpt file
declare @GameAnalysis table
(
	gamingDate          datetime,       -- DE7731
	sessionNbr          int,            -- DE7731
	productGroup        NVARCHAR(64),
	productItemName		NVARCHAR(64),
	sales				MONEY,
	cashPrizes			money,
	merchPrizes			money,
	netProfit			money,
	payoutPct			money,
	holdPct				money
);

   
    declare @Sales table
	    (
            productGroup        NVARCHAR(64),
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
            
            , cashPrizes		money
            , merchPrizes		money
            , otherPrizes		money
            , netProfit			money
            , payoutPct			money
            , holdPct			money
            
	    );

    -- DE7731
    declare @Results table
	    (
            productGroup         NVARCHAR(64),
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
            productGroup         NVARCHAR(64),
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
		    productGroup,
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
    SELECT	rdi.GroupName,
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID = 7
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rdi.GroupName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;         -- DE7731

    -- And take out returns
    INSERT INTO @Sales
	    (
	        productGroup,
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
    SELECT	rdi.GroupName, rdi.ProductItemName, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID = 7
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rdi.GroupName, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    --		
    -- Insert Paper Rows		
    --
    INSERT INTO @Sales
	    (
		    productGroup,
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
    SELECT	rdi.GroupName,rdi.ProductItemName,
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)-- Paper
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName,rdi.ProductItemName,
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 16)
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 2 OR rdi.CardMediaID IS NULL)-- Paper
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    --		
    -- Insert Electronic Rows		
    --
    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName,rdi.ProductItemName,
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 

    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName,rdi.ProductItemName,
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL	
	    AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 

    --		
    -- Insert Credit Rows		
    --
    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName,rdi.ProductItemName, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID BETWEEN 10 AND 13
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName,rdi.ProductItemName, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND rdi.ProductTypeID BETWEEN 10 AND 13
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    --		
    -- Insert Discount Rows		
    --
    -- DE7731: treat discounts like sales
    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName, rdi.ProductItemName, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    AND (rdi.ProductTypeID = 14
	    OR RDI.ProductItemName LIKE 'Discount%')
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName, rdi.ProductItemName, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    AND (rdi.ProductTypeID = 14 or rdi.ProductItemName like 'Discount%')
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


    -- FIX DE8075: Restore original discounts as well as new product-name discounts
    --		
    -- Insert Discount Rows		
    --
    INSERT INTO @Sales
	    (
		    productGroup, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
        and rd.DiscountTypeID IS NOT NULL	
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;

    INSERT INTO @Sales
	    (
	        productGroup,
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
        and rd.DiscountTypeID IS NOT NULL	
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;; 
    -- END FIX DE8075


    --		
    -- Insert Other Rows		
    --
    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName,rdi.ProductItemName, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 1
	    and rr.OperatorID = @OperatorID
	    --AND rdi.ProductTypeID IN (6, 8, 9,14,15, 17)      -- DE7727, DE7729  Show "buy ins"
	    AND rdi.ProductTypeID IN (6, 8, 9, 15, 17)
	    AND RDI.ProductItemName NOT LIKE 'Discount%'
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731

    INSERT INTO @Sales
	    (
		    productGroup,productItemName,
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
    SELECT	rdi.GroupName,rdi.ProductItemName, 
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
    Where 
		(rr.GamingDate between @StartDate and @EndDate)
	    and rr.SaleSuccess = 1
	    and rr.TransactionTypeID = 3 -- Return
	    and rr.OperatorID = @OperatorID
	    --AND rdi.ProductTypeID IN (6, 8, 9, 14, 15, 17)      -- DE7727, DE7729  Show "buy ins"
	    AND rdi.ProductTypeID IN (6, 8, 9, 15, 17)      -- de7731
	    AND RDI.ProductItemName NOT LIKE 'Discount%'    -- de7731
	    And (@Session  = 0 or sp.GamingSession = @Session )
	    and rd.VoidedRegisterReceiptID IS NULL
    GROUP BY rdi.GroupName,rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rdi.ProductTypeID;;         -- DE7731


-- debug
--select * from @Sales;
--return;


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
		    , productGroup nvarchar(64)
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
		    , productGroup
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
		    --, 'Floor Sales'
		    , pg.GroupName
            , pri.ProductTypeID  
	    from InventoryItem 
	    join InvTransaction  on iiInventoryItemID = ivtInventoryItemID
	    join InvTransactionDetail  on ivtInvTransactionID = ivdInvTransactionID
	    join InvLocations  on ivdInvLocationID = ilInvLocationID
	    left join IssueNames  on ivtIssueNameID = inIssueNameID
	    left join ProductItem pri  on pri.ProductItemID = iiProductItemID
	    left join ProductType pt on pri.ProductTypeID = pt.ProductTypeID        -- TC822
	    left join ProductGroup pg on pri.ProductGroupID = pg.ProductGroupID
	    where 
	    (ilMachineID <> 0 or ilStaffID <> 0)
	    and (ivtGamingDate between @StartDate and @EndDate)
	    and (ivtGamingSession = @Session  or @Session  = 0)
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
		    , productGroup
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
            , productGroup
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
            itemName, productGroup, gdate, transDate, gsession, staffid, name
            , itemQty    -- TC822
            , issues, returns, skips, damages, playbacks, bonanzas, price, productTypeId) as
        ( select 
            ProductItemName, productGroup
          , GamingDate, TransDate, GamingSession, StaffID, IssuedLocationName
          , (IssuedCount + ReturnsCount + DamagedCount + SkipCount)  -- ADD since these qtys are negative
          , IssuedCount, ReturnsCount, SkipCount, DamagedCount, PlayBackCount, BonanzaTradeCount, PricePaid
          , ProductTypeId     
          from @IssueData 
        )
	    insert into @Results( 
	      productItemName, productGroup
	    , gamingDate, sessionNbr, staffIdNbr, staffName
	    , itemQty
	    , issueQty, returnQty, skipQty, damageQty
	    , pricePaid
	    , paper, paperSalesFloor, paperSalesTotal, ProductTypeId )
        select 
          p.itemName, p.productGroup
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
        group by p.itemName, p.productGroup, p.gdate, p.gsession, p.staffid, s.LastName, s.FirstName,  p.price, p.productTypeId;


        -- Get our "Subtotals"
        insert into @Results2 
        ( 
          productItemName, productGroup, gamingDate, sessionNbr, staffIdNbr, staffName
          , itemQty
          , issueQty, returnQty, skipQty, damageQty
          , pricePaid
          , paper, paperSalesFloor, paperSalesTotal, ProductTypeId     
        )
        select 
          productItemName, productGroup, gamingDate, sessionNbr, staffIdNbr, staffName
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
        productItemName, productGroup, gamingDate, sessionNbr, staffIdNbr, staffName, pricePaid, ProductTypeId;

            
    -- Walk thru the @results2 temp table holding papersales and update the #Temp table or insert a new record when missing.
    -- The #Temp does not yet contain floor workers w/o register sales.
    declare @productGroup nvarchar(64);
    declare @itemName nvarchar(64);
    declare @staffName nvarchar(64);
    declare @gdate datetime;
    declare @SessionNbr int;
    declare @staffIdNbr int;
    declare @paper money;
    declare @paperSalesFloor money;
    declare @paperSalesTotal money
    declare @itemQty int;
    declare @pricePaid money;
    declare @prodTypeId int;
    set @paper = 0.0;

    declare PAPERCURSOR cursor local fast_forward for 
    select productGroup, productItemName, gamingDate, sessionNbr, staffIdNbr, staffName, itemQty, paperSalesFloor, paperSalesTotal, pricePaid, ProductTypeId
    from @Results2;

    open PAPERCURSOR;
    fetch next from PAPERCURSOR into @productGroup, @itemName, @gdate, @SessionNbr, @staffIdNbr, @staffName, @itemQty, @paperSalesFloor, @paperSalesTotal, @pricePaid, @prodTypeId;
    while(@@FETCH_STATUS = 0)
    begin
        -- Find recs to insert
        set @paper = 0;     -- DE8731: required for conditions where staff has floor w/o register sales
        
        select @paper = paper
        from @Sales 
        where productItemName = @itemName and gamingDate = @gdate and sessionNbr = @SessionNbr and staffIdNbr = @staffIdNbr;

        --print 'DEBUG: ' + convert(nvarchar(10), @paper) + ' ' + @productGroup + ' ' + @itemName + ' ' + convert(nvarchar(10), @gdate) + ' ' + convert(nvarchar(10),@Session Nbr)  + ' ' + @staffName;
        
        if(@paper = 0) -- DE8731: legitimate statement if @paper is properly initialized!
        begin
            insert into @Sales 
            (
              productGroup, productItemName, staffIdNbr, staffName
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
              @productGroup, @itemName, @staffIdNbr, @staffName
            , @gdate, @SessionNbr
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
        where productItemName = @itemName and gamingDate = @gdate and sessionNbr = @SessionNbr and staffIdNbr = @staffIdNbr;
        
        fetch next from PAPERCURSOR into @productGroup, @itemName, @gdate, @SessionNbr, @staffIdNbr, @staffName, @itemQty, @paperSalesFloor, @paperSalesTotal, @pricePaid, @prodTypeId;
    end;

    -- cleanup
    close PAPERCURSOR;
    deallocate PAPERCURSOR;
            
    -- Find total sales
    with SALES (productGroup, productItemName, gamingDate, sessionNbr, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, payouts)
    as
    (
    SELECT	productGroup,
            productItemName,
    	    gamingDate, sessionNbr,
    		SUM( isnull(itemQty, 0)) AS itemQty,
    		SUM( isnull(merchandise, 0)) AS merchandise,
    		SUM( isnull(paper, 0)) AS paper,
            SUM( isnull(paperSalesFloor, 0)) as paperSalesFloor,
            SUM( isnull(paperSalesTotal, 0)) as paperSalesTotal,        
    		SUM( isnull(electronic, 0)) AS electronic,
    		SUM( isnull(credit, 0)) AS credit,
    		SUM( isnull(discount, 0)) AS discount,
    		SUM( isnull(other, 0)) AS other,
    		SUM( isnull(payouts, 0)) AS payouts
    FROM @Sales
    GROUP BY productGroup, productItemName, gamingDate, sessionNbr
    )
    insert into @GameAnalysis
    (
		gamingDate, sessionNbr, productGroup, sales
		, cashPrizes, merchPrizes, netProfit, payoutPct, holdPct
    )
    select 
		gamingDate, sessionNbr, productGroup, 
    	merchandise + paperSalesTotal + electronic + credit + discount + other [Sales] 
    	, 0, 0, 0, 0, 0    
    from SALES;

	-------------------------------------------------------------------------------------------------------------------------------------------------
	--
	-- Payouts and prizes
	--
    
    --
    -- Payouts from Bingo Games
    --
    insert into @GameAnalysis 
    ( 
		productGroup, gamingDate, sessionNbr
		, sales
		, cashPrizes
		, merchPrizes
		, netProfit, payoutPct, holdPct
    )    
    select 
      sgp.GCName, p.GamingDate, sp.GamingSession
    , 0
    , isnull(ptdc.Amount, 0)  + isnull(ptdck.CheckAmount, 0)  + (isnull(ptdcd.NonRefundable, 0) + isnull(ptdcd.Refundable, 0)) [CashPrizes]
    , isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0)  [Merchandise and Other]
    , 0, 0, 0
    
    from PayoutTransBingoGame ptb    -- A bingo game caused the payout, use this as the driver!
    join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
    join PayoutTrans p on ptb.PayoutTransID = p.PayoutTransID

    join TransactionType tt on p.TransTypeID = tt.TransactionTypeID    
    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
    left join PayoutTransDetailCash ptdc on p.PayoutTransID = ptdc.PayoutTransID
    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
    left join PayoutTransDetailCredit ptdcd on p.PayoutTransID = ptdcd.PayoutTransID
    left join PayoutTransDetailMerchandise ptdm on p.PayoutTransID = ptdm.PayoutTransID
    left join PayoutTransDetailOther ptdo on p.PayoutTransID = ptdo.PayoutTransID    
    where 
        (@OperatorID = 0 or p.OperatorID = @OperatorID)
    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
    and (@Session  = 0 or sp.GamingSession = @Session )    
    and tt.TransactionTypeID in (36, 39, 40 );  -- payouts and voids


    --
    -- Payouts from Bingo CUSTOM
    --
    insert into @GameAnalysis 
    ( 
		productGroup, gamingDate, sessionNbr
		, sales
		, cashPrizes
		, merchPrizes
		, netProfit, payoutPct, holdPct
    )    
    select 
      sgp.GCName, p.GamingDate, sp.GamingSession
    , 0
    , isnull(ptdc.Amount, 0)  + isnull(ptdck.CheckAmount, 0)  + (isnull(ptdcd.NonRefundable, 0) + isnull(ptdcd.Refundable, 0)) [CashPrizes]
    , isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0)  [Merchandise and Other]
    , 0, 0, 0
    
    from PayoutTransBingoCustom ptbc    -- A CUSTOM bingo game caused the payout, use this as the driver!
    join SessionGamesPlayed sgp on ptbc.SessionGamesPlayedID = sgp.SessionGamesPlayedID
    join PayoutTrans p on ptbc.PayoutTransID = p.PayoutTransID
    join TransactionType tt on p.TransTypeID = tt.TransactionTypeID    
    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
    left join PayoutTransDetailCash ptdc on p.PayoutTransID = ptdc.PayoutTransID
    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
    left join PayoutTransDetailCredit ptdcd on p.PayoutTransID = ptdcd.PayoutTransID
    left join PayoutTransDetailMerchandise ptdm on p.PayoutTransID = ptdm.PayoutTransID
    left join PayoutTransDetailOther ptdo on p.PayoutTransID = ptdo.PayoutTransID    
    where 
        (@OperatorID = 0 or p.OperatorID = @OperatorID)
    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
    and (@Session  = 0 or sp.GamingSession = @Session )    
    and tt.TransactionTypeID in (36, 39, 40 );  -- payouts and voids


    --
    -- Payouts from Bingo GOOD NEIGHBOR
    --
    insert into @GameAnalysis 
    ( 
		productGroup, gamingDate, sessionNbr
		, sales
		, cashPrizes
		, merchPrizes
		, netProfit, payoutPct, holdPct
    )    
    select 
      sgp.GCName, p.GamingDate, sp.GamingSession
    , 0
    , isnull(ptdc.Amount, 0)  + isnull(ptdck.CheckAmount, 0)  + (isnull(ptdcd.NonRefundable, 0) + isnull(ptdcd.Refundable, 0)) [CashPrizes]
    , isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0)  [Merchandise and Other]
    , 0, 0, 0
    
    from PayoutTransBingoGoodNeighbor ptbgn    -- A GOOD NEIGHBOR bingo game caused the payout, use this as the driver!
    join SessionGamesPlayed sgp on ptbgn.SessionGamesPlayedID = sgp.SessionGamesPlayedID
    join PayoutTrans p on ptbgn.PayoutTransID = p.PayoutTransID
    join TransactionType tt on p.TransTypeID = tt.TransactionTypeID    
    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
    left join PayoutTransDetailCash ptdc on p.PayoutTransID = ptdc.PayoutTransID
    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
    left join PayoutTransDetailCredit ptdcd on p.PayoutTransID = ptdcd.PayoutTransID
    left join PayoutTransDetailMerchandise ptdm on p.PayoutTransID = ptdm.PayoutTransID
    left join PayoutTransDetailOther ptdo on p.PayoutTransID = ptdo.PayoutTransID    
    where 
        (@OperatorID = 0 or p.OperatorID = @OperatorID)
    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
    and (@Session  = 0 or sp.GamingSession = @Session )    
    and tt.TransactionTypeID in (36, 39, 40 );  -- payouts and voids

    --
    -- Payouts from Bingo ROYALTY
    --
    insert into @GameAnalysis 
    ( 
		productGroup, gamingDate, sessionNbr
		, sales
		, cashPrizes
		, merchPrizes
		, netProfit, payoutPct, holdPct
    )    
    select 
      sgp.GCName, p.GamingDate, sp.GamingSession
    , 0
    , isnull(ptdc.Amount, 0)  + isnull(ptdck.CheckAmount, 0)  + (isnull(ptdcd.NonRefundable, 0) + isnull(ptdcd.Refundable, 0)) [CashPrizes]
    , isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0)  [Merchandise and Other]
    , 0, 0, 0
    
    from PayoutTransBingoRoyalty ptbr    -- A ROYALTY bingo game caused the payout, use this as the driver!
    join SessionGamesPlayed sgp on ptbr.SessionGamesPlayedID = sgp.SessionGamesPlayedID
    join PayoutTrans p on ptbr.PayoutTransID = p.PayoutTransID
    join TransactionType tt on p.TransTypeID = tt.TransactionTypeID    
    join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
    left join PayoutTransDetailCash ptdc on p.PayoutTransID = ptdc.PayoutTransID
    left join PayoutTransDetailCheck ptdck on p.PayoutTransID = ptdck.PayoutTransID
    left join PayoutTransDetailCredit ptdcd on p.PayoutTransID = ptdcd.PayoutTransID
    left join PayoutTransDetailMerchandise ptdm on p.PayoutTransID = ptdm.PayoutTransID
    left join PayoutTransDetailOther ptdo on p.PayoutTransID = ptdo.PayoutTransID    
    where 
        (@OperatorID = 0 or p.OperatorID = @OperatorID)
    and (p.GamingDate >= @StartDate and p.GamingDate <= @EndDate)
    and (@Session  = 0 or sp.GamingSession = @Session )    
    and tt.TransactionTypeID in (36, 39, 40 );  -- payouts and voids


	-- PRODUCTION
	with GAMEANALYSIS( gDate, sessionNbr, productGroup, sales, cash, merch) as 
	(select 
	gamingDate, sessionNbr, productGroup
	, SUM(sales)		[Sales]
	, SUM(cashPrizes)	[Cash Prizes]
	, SUM(merchPrizes)	[Merch Prizes]
	from @GameAnalysis  
	group by gamingDate, sessionNbr, productGroup)
	select 
	  gDate
	, sessionNbr
	, productGroup
	, sales
	, cash
	, merch
	, (sales - cash - merch) [NetProfit]
	, case 
		when sales = 0 then 0
		else ((cash + merch) / sales) * 100   -- for proper pct % value
	  end	[Payout Pct]
	, case 
		when sales = 0 then 0
		else ((sales - cash - merch) / sales) * 100
	  end [Hold Pct]

	from GAMEANALYSIS
	order by productGroup;

end;
set nocount off;

GO


