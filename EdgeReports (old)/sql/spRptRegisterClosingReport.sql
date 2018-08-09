USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReport]    Script Date: 08/09/2012 09:58:05 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReport]    Script Date: 08/09/2012 09:58:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO












CREATE PROCEDURE [dbo].[spRptRegisterClosingReport]
(
---- =============================================
---- Author:		Barry Silver
---- Description:	Receipt style closing report
----
---- 05/19/2011 BJS: DE8480,8481 restore original discounts
---- 06/24/2011 bjs: DE8480,81,82 missing floor sales
---- 06/30/0211 bjs: show session 0 bank activity in other sessions
---- 2011.07.05 bjs: DE8480 missing banks and drops
---- 2011.07.20 bjs: Mohawk Beta fix for Session=NA
---- 2011.08.17 bjs: DE9073: drops doubled for NA sessions
---- 2011.10.31 bsb: DE9573: added cash payouts
---- 2012.1.24  SA : DE9937: missing machineId for papersales 
-----2012.2.16 bsb: DE10028: added cash payouts to session summary
-----2012.3.13 kc :DE10189: device fees incorrect
---- 2012.7.3 kc :DE10561: 
---- 2012.08.06 kc:DE10462: Fixed calculation on other, concession, and merchandise sales.
---- 2012.08.09 kc:DE10589: Regular pay for cash and checked prize fees fixed.
---- =============================================

--declare
	@OperatorID	AS	INT,
	@StartDate	AS	DATETIME,
	@EndDate	AS	DATETIME,
	@StaffID    AS  INT,
	@Session	AS	INT,
	@MachineID	AS	INT
)	
as
begin
set nocount on;

--set @EndDate = '8/09/2012 00:00:00'
--set @MachineID = 0
--set @OperatorID = 1
--set @Session = 1
--set @StaffID = 4
--set @StartDate = '8/09/2012 00:00:00'




-- Verfify POS sending valid values
set @StaffID = isnull(@StaffID, 0);
set @Session = isnull(@Session, 0);
set @MachineID = isnull(@MachineID, 0);

-- When in Machine Mode (2) display all staff members when printing
declare @CashMethod int;
select @CashMethod = CashMethodID from Operator
where OperatorID = @OperatorID;

-- debug
print 'Cash Method: ' + convert(nvarchar(5), @CashMethod);

-- Results table	
declare @ClosingResults table
	(
	    opId				int,			-- DE8480 so Sales Activity subrpt shows only for Money Center mode
		productItemName		NVARCHAR(128),
		staffIdNbr          int,            -- DE7731
		staffLastName       NVARCHAR(64),
		staffFirstName      NVARCHAR(64),
		price               money,          -- DE7731
		gamingDate          datetime,       -- DE7731
		sessionNbr          int,            -- DE7731
		soldFromMachineId   int,
		itemQty				INT,
		merchandise			MONEY,
		paper				MONEY,          -- original field, represents paper sales made at a register
		paperSalesFloor 	MONEY,          -- DE7731
		paperSalesTotal 	MONEY,          -- DE7731
		electronic			MONEY,
		credit				MONEY,
		discount			MONEY,
		other				MONEY
		, bingoPayouts money
    	, pullTabPayouts money
    	, Taxes money
    	, Fees  money
	    , BanksIssuedTo MONEY
	    , BanksIssuedFrom MONEY
	    , DropsTo MONEY
	    , TotalDue MONEY
	    , TotalDrop MONEY
	    , OverShort MONEY
		, pullTabSales money
		, sessionPlayedId int			
		, progressivePayouts money
		, prizeFees money
	);

		
--		
-- Insert Merchandise Rows		

INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,    -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,    
		electronic,
		credit,
		discount,
		other
		, bingoPayouts
		, pullTabPayouts
		, sessionPlayedId		
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,   -- DE7731
        rr.SoldFromMachineID,
		SUM(rd.Quantity * rdi.Qty),
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, 0, 0  -- bingo and pulltab payouts	
		, sp.SessionPlayedID	
		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID = 7  or rdi.ProductTypeID = 6)
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731




--B 
-- And take out returns
INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
        rr.SoldFromMachineID,
		SUM(-1 * rd.Quantity * rdi.Qty),
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00, 0.00, 0.00,
		0.00,
		0.00,
		0.00,
		0.00
		, 0, 0  -- bingo and pulltab payouts
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
AND (rdi.ProductTypeID = 7  or rdi.ProductTypeID = 6)
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731



--C	
-- Insert Electronic Rows		
--had a value
INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
		rr.SoldFromMachineID,
		SUM(rd.Quantity * rdi.Qty),--itemQty,
		0.0,--merchandise,
		0.0, 0.0, 0.0, --paper,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		0.0,--credit,
		0.0,--discount,
		0.0 --other,
		, 0, 0  -- bingo and pulltab payouts
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	--JOIN #TempDevicePerReceipt dpr ON (dpr.registerReceiptID = rr.RegisterReceiptID)
	--LEFT JOIN Device d ON (d.DeviceID = dpr.deviceID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731
--D  


INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
		rr.SoldFromMachineID,
		SUM(-1 * rd.Quantity * rdi.Qty),--itemQty,
		0.0,--merchandise,
		0.0,0.0,0.0, --paper,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),--electronic,
		0.0,--credit,
		0.0,--discount,
		0.0 --other,
		, 0, 0  -- bingo and pulltab payouts
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (1, 2, 3, 4, 5)
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL	
	AND (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731




--E  
--		
-- Insert Credit Rows		
--
INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
		rr.SoldFromMachineID,
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00
		, 0, 0  -- bingo and pulltab payouts
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID BETWEEN 10 AND 13
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731
--F 



INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
        soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
        rr.SoldFromMachineID,
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00,
		0.00
		, 0, 0  -- bingo and pulltab payouts
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID BETWEEN 10 AND 13
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731



--G 
--		
-- Insert Discount Rows		
--
-- DE7731: treat discounts like sales
INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
		rr.SoldFromMachineID,
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price),
		0.00
		, 0, 0  -- bingo and pulltab payouts
		,sp.SessionPlayedID		
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID = 14	and RDI.ProductItemName LIKE 'Discount%')
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731

--H 

INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
        rr.SoldFromMachineID,
		SUM(-1 * rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price),
		0.00
		, 0, 0  -- bingo and pulltab payouts
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID = 14 and rdi.ProductItemName like 'Discount%')
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731

--I 


-- FIX DE8480,8481: Restore original discounts as well as new product-name discounts
--		
-- Insert Discount Rows		
--
INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, dt.DiscountTypeName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName,                     
		rr.SoldFromMachineID,
		SUM(rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),
		0.00,
		0.00, 0
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )
	join Staff s on rr.StaffID = s.StaffID
WHERE rd.DiscountTypeID IS NOT NULL	
	AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;
--J  



INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, dt.DiscountTypeName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName,                     
		rr.SoldFromMachineId,
		SUM(-1 * rd.Quantity),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		SUM(rd.Quantity * rd.DiscountAmount),       -- TODO should this be multiplied by -1??????????????
		0.00,
		0.00, 0
		,sp.SessionPlayedID
FROM RegisterReceipt rr
	left JOIN RegisterDetail rd ON ( rr.RegisterReceiptID = rd.RegisterReceiptID )
	left JOIN RegisterDetailItems rdi ON ( rd.RegisterDetailID = rdi.RegisterDetailID )
	LEFT JOIN SessionPlayed sp ON ( rd.SessionPlayedID = sp.SessionPlayedID )
	left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID)
	left join Staff s on rr.StaffID = s.StaffID
WHERE rd.DiscountTypeID IS NOT NULL	
	AND rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;


-- END FIX DE8480,8481
--K 


--select * from @ClosingResults;

--		
-- Insert Other Rows		
--
INSERT INTO @ClosingResults
	(
		opId,
		productItemName,
		staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
		soldFromMachineId,
		itemQty,
		merchandise,
		paper, paperSalesFloor, paperSalesTotal,
		electronic,
		credit,
		discount,
		other,
		bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)
SELECT	rr.OperatorID, rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
		rr.SoldFromMachineID,
		SUM(rd.Quantity * rdi.Qty),
		0.00,
		0.00, 0.0, 0.0, 
		0.00,
		0.00,
		0.00,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
		, 0, 0  -- bingo and pulltab payouts
		, sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID IN (6, 8, 9, 15) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))	-- bjs 5/24/11 exclude pulltabs
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
      and ProductTypeID = 14 
      and BarCode is null --DE10564:kc:8/6/2012
      /*DeviceID, PackNumber, StartsNumber*/
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731
--L 




INSERT INTO @ClosingResults
(
	opId,
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffLastName, staffFirstName,       -- DE7731
	soldFromMachineId,
	itemQty,
	merchandise,
	paper, paperSalesFloor, paperSalesTotal,
	electronic,
	credit,
	discount,
	other,
	bingoPayouts, pullTabPayouts
	,sessionPlayedId
)
SELECT	rr.OperatorID, rdi.ProductItemName, 
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
	SUM(-1 * rd.Quantity * rdi.Qty),
	0.00,
	0.00, 0.0, 0.0, 
	0.00,
	0.00,
	0.00,
	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	, 0, 0  -- bingo and pulltab payouts
	,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	and rr.OperatorID = @OperatorID
	AND (rdi.ProductTypeID IN (/*6,*/ 8, 9, 15) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' ))	-- bjs 5/24/11 exclude pulltabs
	And (@Session = 0 or sp.GamingSession = @Session)
	and rd.VoidedRegisterReceiptID IS NULL
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731




---- DEBUG
--select * from @ClosingResults;
--return;

--M 

-- Add in the pull tab sales records
--
INSERT INTO @ClosingResults
	(
		opId,
		gamingDate,
		sessionNbr,
        staffIdNbr,
		StaffLastName,
		StaffFirstName,
		soldFromMachineId,
		PullTabSales
		, ProductItemName
        --, Qty
        ,sessionPlayedId
	)
SELECT	rr.OperatorID, rr.GamingDate,
		ISNULL(sp.GamingSession, 0),
        s.StaffID,
		s.LastName,
		s.FirstName,
		rr.SoldFromMachineID,
		SUM(rd.Quantity * rdi.Qty * rdi.Price)
		, rdi.ProductItemName
		--, sum(rd.Quantity * rdi.Qty)
		,sp.SessionPlayedID
FROM RegisterReceipt rr		
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN Staff s ON (s.StaffID = rr.StaffID)
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	AND rr.TransactionTypeID = 1
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (17)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, s.StaffID, s.LastName, s.FirstName, rdi.ProductItemName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731
--N 



INSERT INTO @ClosingResults
	(
		opId,
		gamingDate,
		sessionNbr,
        staffIdNbr,
		StaffLastName,
		StaffFirstName,
		soldFromMachineId,
		PullTabSales
        , ProductItemName
        ,sessionPlayedId
	)
SELECT	rr.OperatorID, rr.GamingDate,
		ISNULL(sp.GamingSession, 0),
        s.StaffID,
		s.LastName,
		s.FirstName,
		rr.SoldFromMachineID,
		SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)
		, rdi.ProductItemName
		,sp.SessionPlayedID
FROM RegisterReceipt rr		
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN Staff s ON (s.StaffID = rr.StaffID)
WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	AND rr.SaleSuccess = 1
	and rr.TransactionTypeID = 3 -- Return
	AND rr.OperatorID = @OperatorID
	AND rdi.ProductTypeID IN (17)
	AND (@Session = 0 or sp.GamingSession = @Session)
	AND rd.VoidedRegisterReceiptID IS NULL	
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, s.StaffID, s.LastName, s.FirstName, rdi.ProductItemName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731



--O 

-- Taxes
--
INSERT INTO @ClosingResults
	(
		opId,
		gamingDate,
		sessionNbr,
        staffIdNbr,
		staffLastName, staffFirstName,
		soldFromMachineId,
		Taxes
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
		,sessionPlayedId
	)   
SELECT	rr.OperatorID,
    rr.GamingDate,
	ISNULL(convert(int, sp.GamingSession), -1),		-- 2011.07.22 bjs: allow for all-day n/a sessions
    s.StaffID, s.LastName, s.FirstName,
	rr.SoldFromMachineID,
	SUM(rd.SalesTaxAmt * rd.Quantity)		-- DE8480
	, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	,sp.SessionPlayedID
FROM RegisterReceipt rr
	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	JOIN Staff s ON (s.StaffID = rr.StaffID)
Where 
    (rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime))
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID IN (1, 3)
	and rd.VoidedRegisterReceiptID IS NULL	
	and (@OperatorID = 0 or rr.OperatorID = @OperatorID )
	And (@Session = 0 or sp.GamingSession = @Session)
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )    
GROUP BY rr.OperatorID, rr.GamingDate, sp.GamingSession, s.StaffID, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;




--P
-- FEES
--
INSERT INTO @ClosingResults
	(
		opId,
		gamingDate,
		sessionNbr,
        staffIdNbr,
		staffLastName, staffFirstName,
		soldFromMachineId,
		Fees
		, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
		
	)    	
SELECT	rr.OperatorID, rr.GamingDate,
	(SELECT TOP 1 ISNULL(sp2.GamingSession, 0) FROM RegisterReceipt rr2
		JOIN RegisterDetail rd2 ON (rr2.RegisterReceiptID = rd2.RegisterReceiptID)
		LEFT JOIN SessionPlayed sp2 ON (sp2.SessionPlayedID = rd2.SessionPlayedID)
		WHERE rr2.RegisterReceiptID = rr.RegisterReceiptID
		ORDER BY sp2.GamingSession),
    s.StaffID, s.LastName, s.FirstName,
    rr.SoldFromMachineID,
	isnull(rr.DeviceFee, 0)
    , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    
FROM RegisterReceipt rr
	JOIN Staff s ON (s.StaffID = rr.StaffID)
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
	And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and rr.TransactionTypeID = 1
	and rr.OperatorID = @OperatorID
	AND rr.DeviceFee IS NOT NULL
	AND rr.DeviceFee <> 0 
	AND EXISTS (SELECT * FROM RegisterDetail WHERE RegisterReceiptID = rr.RegisterReceiptID AND VoidedRegisterReceiptID IS NULL)
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  or @CashMethod = 2);
    
    
    
    
---- DEBUG

--return;
--		
-- Insert Payout Rows		
--Q 



insert into @ClosingResults
(
  opID,
  gamingDate, 
  sessionNbr,
  staffIdNbr,
  staffLastName, staffFirstName,
  bingoPayouts,
  prizeFees,
  sessionPlayedId
)
--PayoutTransBingoGame
select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID
      ,ss.LastName, ss.FirstName,  ptdc.DefaultAmount, pt.PrizeFee, sp.SessionPlayedID
from PayoutTransDetailCash ptdc
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID
 left join PayoutTransBingoGame ptb on ptdc.PayoutTransID = ptb.PayoutTransID
 join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
 join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
 join Staff ss on pt.StaffID = ss.StaffID
 where pt.OperatorID = @OperatorID
 and (@StaffID = 0 or pt.StaffID = @StaffID )
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)
 and (@Session = 0 or sp.GamingSession = @Session)
 and (@MachineID = 0 or pt.MachineID = @MachineID)
  and pt.voidtransid is null
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc 
  ; 



  
-- insert into @ClosingResults
--(
--  opID,
--  gamingDate, 
--  sessionNbr,
--  staffIdNbr,
--  staffLastName, staffFirstName,
--  bingoPayouts,
--  prizeFees,
--  sessionPlayedId
--)
----PayoutTransBingoGame
--select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID
--      ,ss.LastName, ss.FirstName,  0, pt.PrizeFee, sp.SessionPlayedID
--from PayoutTransDetailCheck ptdc
--join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID
-- left join PayoutTransBingoGame ptb on ptdc.PayoutTransID = ptb.PayoutTransID
-- join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
-- join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
-- join Staff ss on pt.StaffID = ss.StaffID
-- where pt.OperatorID = @OperatorID
-- and (@StaffID = 0 or pt.StaffID = @StaffID )
-- and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)
-- and (@Session = 0 or sp.GamingSession = @Session)
-- and (@MachineID = 0 or pt.MachineID = @MachineID)
--  and pt.voidtransid is null
--  and pt.AccrualTransID is null --7/3/2012 DE10561 kc 

  







 --R 
 --PayoutTransBingoCustom
 insert into @ClosingResults
(
  opID,
  gamingDate, 
  sessionNbr,
  staffIdNbr,
  staffLastName, staffFirstName,
  bingoPayouts,
  prizeFees,
  sessionPlayedId
)
select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID
      ,ss.LastName, ss.FirstName,  ptdc.DefaultAmount, pt.PrizeFee, sp.SessionPlayedID
from PayoutTransDetailCash ptdc
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID
 left join PayoutTransBingoCustom ptb on ptdc.PayoutTransID = ptb.PayoutTransID
 join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
 join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
 join Staff ss on pt.StaffID = ss.StaffID
 where pt.OperatorID = @OperatorID
 and (@StaffID = 0 or pt.StaffID = @StaffID )
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)
 and (@Session = 0 or sp.GamingSession = @Session)
 and (@MachineID = 0 or pt.MachineID = @MachineID)
  and pt.voidtransid is null;


  --S 
insert into @ClosingResults
(
  opID,
  gamingDate, 
  sessionNbr,
  staffIdNbr,
  staffLastName, staffFirstName,
  bingoPayouts,
  prizeFees,
  sessionPlayedId
)

select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID
      ,ss.LastName, ss.FirstName,  ptdc.DefaultAmount, pt.PrizeFee, sp.SessionPlayedID
from PayoutTransDetailCash ptdc
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID
  left join PayoutTransBingoGoodNeighbor ptb on ptdc.PayoutTransID = ptb.PayoutTransID
 join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
 join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
 join Staff ss on pt.StaffID = ss.StaffID
 where pt.OperatorID = @OperatorID
 and (@StaffID = 0 or pt.StaffID = @StaffID )
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)
 and (@Session = 0 or sp.GamingSession = @Session)
 and (@MachineID = 0 or pt.MachineID = @MachineID)
  and pt.voidtransid is null;
  
  
  
  --T 
 --PayoutTransBingoRoyalty
   insert into @ClosingResults
(
  opID,
  gamingDate, 
  sessionNbr,
  staffIdNbr,
  staffLastName, staffFirstName,
  bingoPayouts,
  prizeFees,
  sessionPlayedId
)

select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID
      ,ss.LastName, ss.FirstName,  ptdc.DefaultAmount, pt.prizeFee, sp.SessionPlayedID
from PayoutTransDetailCash ptdc
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID
 left join PayoutTransBingoRoyalty ptb on ptdc.PayoutTransID = ptb.PayoutTransID
 join SessionGamesPlayed sgp on ptb.SessionGamesPlayedID = sgp.SessionGamesPlayedID
 join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
join Staff ss on pt.StaffID = ss.StaffID
 where pt.OperatorID = @OperatorID
 and (@StaffID = 0 or pt.StaffID = @StaffID )
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)
 and (@Session = 0 or sp.GamingSession = @Session)
 and (@MachineID = 0 or pt.MachineID = @MachineID)
  and pt.voidtransid is null;




--OLD kc/DE10589/8.8.2012
-- Progressive Payouts 
insert into @ClosingResults
(
  opID,
  gamingDate, 
  sessionNbr,
  staffIdNbr,
  staffLastName, staffFirstName,
  progressivePayouts,
  prizeFees,
  sessionPlayedId
)
select   pt.OperatorID
        ,pt.GamingDate
        ,sp.GamingSession
        ,pt.StaffID
        ,ss.LastName
        ,ss.FirstName
        ,ISNULL(ptdc.DefaultAmount, 0.00)
        ,pt.PrizeFee
        ,sp.SessionPlayedID
from AccrualTransactionDetails atd
    join PayoutTrans pt on atd.AccrualTransactionId = pt.AccrualTransID
    join AccrualTransactions at on pt.AccrualTransId = at.AccrualTransactionId 
    join SessionPlayed sp on at.SessionPlayedID = sp.SessionPlayedID
    join Staff ss on pt.StaffID = ss.StaffID
    join PayoutTransDetailCash ptdc on pt.PayoutTransID = ptdc.PayoutTransID   
 where pt.OperatorID = @OperatorID
    and (@StaffID = 0 or pt.StaffID = @StaffID)
    and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)
    and (@Session = 0 or sp.GamingSession = @Session)
    and (@MachineID = 0 or pt.MachineID = @MachineID)
    and pt.voidtransid is null;




-------------------------------------------------------
-- Banks
-------------------------------------------------------

-- FIX DE8853
-- Money Center mode have true Master and Staff Banks.  Show only staff banks here (original code).
if(@CashMethod = 3)
begin
--U = 3
-- Get banks issued to our staff member
INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedTo
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT b.bkOperatorID,	ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND b.bkBankTypeID = 2
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;
--V = 0
-- Get banks issued from our staff member


INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedFrom
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT	b.bkOperatorID, ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineId,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID)    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND b.bkBankTypeID = 2
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;
--X = 0
-- Get banks dropped to our staff member


INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	DropsTo
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT	b.bkOperatorID, ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN ( 20, 29) -- Bank Closes and Drops too
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID)   
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND b.bkBankTypeID = 2
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;
--Y = 3
-- Get banks dropped from our staff member

INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	TotalDrop
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT	b.bkOperatorID, ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (20, 29) -- Drops and Bank Closes (implicit drops)
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
	AND b.bkBankTypeID = 2
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;		

end
else if(@CashMethod = 1)   -- POS mode
begin
-- POS Mode has banks, no drops


-- Get banks issued to our staff member
INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedTo
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT b.bkOperatorID,	ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineID,
        SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    --and (@MachineID = 0 or b.bkMachineID = @MachineID )       
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName,b.bkMachineID;



-- Get banks issued from our staff member
INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedFrom
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT	b.bkOperatorID, ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        s.StaffID, s.LastName , s.FirstName,
        b.bkMachineId,    
    	SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
	JOIN Staff s ON (s.StaffID = b.bkStaffID)
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks
	AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks
	AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@StaffID = 0 or b.bkStaffID = @StaffID)
    --and (@MachineID = 0 or b.bkMachineID = @MachineID )     
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID;

end
else if(@CashMethod = 2)   -- MACHINE mode
begin
	print 'MACHINE MODE BANK ACTIVITY';
-- MACHINE Mode has a shared master banks in a separate group.  No drops!

-- Get banks issued to our staff member
INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedTo
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT b.bkOperatorID,	ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        b.bkStaffID, 'Bank', 'Master', 
        b.bkMachineID,
		SUM(ISNULL(ctd.ctrdDefaultTotal, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
WHERE 
	b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID, b.bkMachineID;



-- Get banks issued from our staff member
INSERT INTO @ClosingResults
(
	opId,
	gamingDate, 
	sessionNbr,
    staffIdNbr,
	staffLastName, staffFirstName,
	soldFromMachineId,
	BanksIssuedFrom
	, price, itemQty, merchandise, paper, paperSalesFloor, paperSalesTotal, electronic, credit, discount, other, bingoPayouts, pullTabPayouts
)
SELECT	b.bkOperatorID, ct.ctrGamingDate,
		case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,
        b.bkStaffID, 'Bank', 'Master', 
        b.bkMachineId,
		SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
FROM CashTransaction ct
	JOIN Bank b ON (ct.ctrSrcBankID = b.bkBankID)
	JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)
WHERE 
	b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.
	AND ct.ctrTransactionTypeID IN (11,17) -- Issues Only
	AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range
	AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range
	AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided
    and (@MachineID = 0 or b.bkMachineID = @MachineID )    
	and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, b.bkStaffID, b.bkMachineID;

end;	-- END MACHINE MODE

--select * from @ClosingResults 

---- debug
--select * from @ClosingResults;
--return;

--
-- Paper sales: both register sales and inventory (floor sales)
-- 
--Z = 18
insert @ClosingResults
(
	opId
	, productItemName
	, staffIdNbr, staffLastName, staffFirstName
	, price
	, gamingDate
	, sessionNbr
	, soldFromMachineId
	, itemQty
	, merchandise
	, paper, paperSalesFloor, paperSalesTotal
	, electronic
	, credit
	, discount
	, other
	, bingoPayouts
	, pullTabPayouts
	, Taxes
	, BanksIssuedTo 
	, BanksIssuedFrom 
	, DropsTo 
	, TotalDue 
	, TotalDrop 
	, OverShort 
	, pullTabSales 
)
select 
	@OperatorID,
		ItemName
	, fps.StaffID, s.LastName, s.FirstName
	, Price, GamingDate, SessionNo
	, fps.soldFromMachineId
	, Qty
	, 0
	, RegisterPaper, FloorPaper, RegisterPaper + FloorPaper
	, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	
from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps
join Staff s on fps.StaffID = s.StaffID
where 
    (@StaffID = 0 or s.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
    and (@MachineID = 0 or fps.soldFromMachineId = @MachineID )











---- Calculate our row totals
--UPDATE @ClosingResults
--set paperSalesTotal = (paper + paperSalesFloor);

declare @ResultSet table
(
	opId				int,
	staffId             int,            -- DE7731
	gamingDate          datetime,       -- DE7731
	sessionNbr          int,            -- DE7731
	LastName            NVARCHAR(64),
	FirstName           NVARCHAR(64),
	soldFromMachineId   int,
	electronic			MONEY,
	paper				money,
	merchandise			money,
	discount			MONEY,
	other				MONEY,
	cashPayout          MONEY	
	, pullTabPayouts    money
	, pullTabSales      money
	, Taxes             money
	, Fees              money
    , TotalBanks        MONEY
    , TotalDrop         MONEY
    , TotalDue          MONEY
    , OverShort         MONEY
    , sessionPlayedID int
	, progressivePayouts money
	, prizeFees money
);



-- HACK to overcome problem with empty rows in crystal report
--AA = 0
with RESULTS(
  opId
, staffId, gamingDate, sessionNbr, LastName, FirstName
, soldFromMachineId
, electronic
, paper
, merchandise
, discount, other, cashPayout, pullTabPayouts, pullTabSales
, taxes, fees, TotalBanks, TotalDrop, TotalDue, OverShort,sessionPlayedId
, progressivePayouts, prizeFees)
as
(SELECT	
	  opId
    , staffIdNbr [staffId]
    , gamingDate
	, isnull(sessionNbr, -1)	 [sessionNbr]			-- 2011.07.22 bjs: allow for day-long, N/A sessions
    , stafflastName [LastName]
    , staffFirstName [FirstName]
    , isnull(soldFromMachineId, 0) [soldFromMachineId]
	, SUM(isnull(electronic, 0)) [electronic]
	
	, sum(isnull(paperSalesTotal, 0)) [paper]
	, sum(isnull(merchandise, 0)) [merchandise]
	
	, SUM(isnull(discount, 0)) [discount]
	, SUM(isnull(other, 0)) [other]
	, SUM(isnull(bingopayouts,0))[cashpayout]
	, SUM(isnull(pullTabPayouts, 0)) [pullTabPayouts]
	, SUM(ISNULL(pullTabSales, 0)) [pullTabSales]
	, SUM(isnull(taxes, 0)) [taxes]
	, SUM(isnull(fees, 0)) [fees]
	, (SUM(ISNULL(BanksIssuedTo, 0)) + SUM(ISNULL(BanksIssuedFrom, 0))) [TotalBanks] 
	, (SUM(ISNULL(DropsTo, 0))+ SUM(ISNULL(TotalDrop, 0))) [TotalDrop]  
	--, SUM(ISNULL(TotalDrop, 0)) [TotalDrop]  --DE8480 ?
	, SUM(ISNULL(TotalDue, 0)) [TotalDue]
	, SUM(ISNULL(OverShort, 0)) [OverShort]
	, sessionPlayedId
	, sum(isnull(progressivePayouts, 0)) [ProgressivePayouts]
	, sum(isnull(prizeFees, 0)) [PrizeFees]
FROM @ClosingResults
--where sessionNbr = @Session 
GROUP BY opId, staffIdNbr, gamingDate, sessionNbr, staffLastName, staffFirstName, soldFromMachineId, sessionPlayedId)

insert into @ResultSet
select 
  opId
, staffId, gamingDate, sessionNbr, LastName, FirstName
, soldFromMachineId
, electronic
, paper
, merchandise
, discount, other, cashPayout, pullTabPayouts, pullTabSales
, taxes, fees, TotalBanks, TotalDrop, TotalDue, OverShort,sessionPlayedId
, ProgressivePayouts, PrizeFees
from RESULTS
where    (@StaffID = 0 or staffId = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
ORDER BY staffId, gamingDate, sessionNbr ;

-- 2011.07.22 bjs: Mohawk beta fix
UPDATE @ResultSet
SET TotalBanks = (SELECT MAX (TotalBanks) FROM @ResultSet)
	,TotalDrop = (SELECT MIN(TotalDrop) FROM @ResultSet)
WHERE sessionNbr IS NULL;



--------------------------------------------------------------------------------------
---- Add in Cash payout --DE9573

 --Update @ResultSet
 --SET cashPayout = dbo.GetRegisterCashPayouts(@OperatorID,@MachineID, @StaffID,@StartDate,@EndDate);
--declare @sessionPlayedId int;
--declare results_cursor cursor
--   for select sessionPlayedID from @ResultSet;
--open results_cursor
--fetch next from results_cursor into @sessionPlayedId;
--while @@FETCH_STATUS =0
--begin
--    update @ResultSet
--    set cashPayout = dbo.GetSessionBingoCashPayouts(@sessionPlayedId)
--    where sessionPlayedId = @sessionPlayedId;
--    fetch next from results_cursor into @sessionPlayedId;
--end;
--close results_cursor;
--deallocate results_cursor;

					
---------------------------------------------------------------------------------------
---- DEBUG
--select * from @ClosingResults;
--select * from @ResultSet;
--return;

--select * from @ResultSet 

--AB = 0
with NOBLANKROWS
(
	opId, cashMethodId
  , staffId, gamingDate, sessionNbr, LastName, FirstName, soldFromMachineId
  , electronic
  , paper
  , merchandise
  , discount
  , other
  , cashPayout
  , pullTabPayouts, pullTabSales
  , taxes, fees
  , TotalBanks, TotalDrop, TotalDue, OverShort
  , Checker
  , sessionPlayedID
  , ProgressivePayouts
  , PrizeFees
)
as
(select 
	opId, CashMethodID
  , staffId, gamingDate, sessionNbr, LastName, FirstName, soldFromMachineId
  , electronic
  , paper
  , merchandise
  , discount
  , other,cashPayout, pullTabPayouts, pullTabSales, taxes, fees, TotalBanks, TotalDrop, TotalDue, OverShort
, isnull((electronic + discount + other + pullTabPayouts + pullTabSales + taxes + fees + TotalBanks + TotalDrop + TotalDue + OverShort + ProgressivePayouts + PrizeFees), 0) [Checker]
, sessionPlayedID
, ProgressivePayouts
, PrizeFees
from @ResultSet
join Operator o on opId = o.OperatorID
)

select 
  opId [OperatorID]
, CashMethodID
, staffId, gamingDate
, sessionNbr
, LastName, FirstName, soldFromMachineId
, electronic
, paper
, merchandise
, discount, other,cashPayout, pullTabPayouts, pullTabSales, taxes, 
--FIXED Karlo Camacho 3/13/2012
fees = case 
when @Session = 2 and sessionNbr = 1 then 0.00 
when @Session = 1 and sessionNbr = 2 then 0.00
else fees
end
, TotalBanks, TotalDrop, TotalDue, OverShort,sessionPlayedID,ProgressivePayouts, PrizeFees
from NOBLANKROWS
where (sessionNbr = @Session or @Session = 0)
--where Checker <> 0    -- restore this if needed to filter out blank rows!
ORDER BY staffId, gamingDate, sessionNbr;

END















GO


