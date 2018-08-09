USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReport]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptRegisterClosingReport]      
(      
---- =============================================      
---- Author:  Barry Silver      
---- Description: Receipt style closing report      
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
---- 2012.08.15 oas:Fixed custom payout prize fees
---- 2013.12.24 jkn: DE11488 Fixed issue with sp failing
---- 2014.04.22 jkn DE11719 Fixed issue with multiple banks being returned when
---- and override has been sent this would cause the report to be off by the
---- number of overrides sent.      
---- 2014.10.29 tmp: US3735: Added master bank activity.
-- 20150918 knc: Add coupon sales.
---- =============================================      
      
 @OperatorID AS INT,      
 @StartDate AS DATETIME,      
 @EndDate AS DATETIME,      
 @StaffID    AS  INT,      
 @Session AS INT,      
 @MachineID AS INT      
)       
as      
begin      
set nocount on;      
                  
-- Verfify POS sending valid values      
declare @StaffID2 int
set @StaffID2 = @StaffID 



if @StaffID is null
begin
set @StaffID = isnull(@StaffID, 0);  
end
else
begin set @StaffID = 0 end     

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
	  opId    int,   -- DE8480 so Sales Activity subrpt shows only for Money Center mode      
	  productItemName  NVARCHAR(128),      
	  staffIdNbr          int,            -- DE7731      
	  staffLastName       NVARCHAR(64),      
	  staffFirstName      NVARCHAR(64),      
	  price               money,          -- DE7731      
	  gamingDate          datetime,       -- DE7731      
	  sessionNbr          int,            -- DE7731      
	  soldFromMachineId   int,      
	  itemQty    INT,      
	  merchandise   MONEY,      
	  paper    MONEY,          -- original field, represents paper sales made at a register      
	  paperSalesFloor  MONEY,          -- DE7731      
	  paperSalesTotal  MONEY,          -- DE7731      
	  electronic   MONEY,      
	  credit    MONEY,      
	  discount   MONEY,    
	  coupon   MONEY,   
	  other    MONEY      
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

-- Insert Coupon Rows

INSERT INTO @ClosingResults      
 (      
  opId,      
  productItemName,      
  staffIdNbr, 
  price, 
  gamingDate, 
  sessionNbr, 
  staffLastName, 
  staffFirstName,    -- DE7731      
  soldFromMachineId,      
  itemQty,      
  merchandise,      
  paper, 
  paperSalesFloor, 
  paperSalesTotal,          
  electronic,      
  credit,      
  discount, 
  coupon,    
  other      
  , bingoPayouts      
  , pullTabPayouts      
  , sessionPlayedId        
 )   
 
 select 
 @OperatorID, CouponName, cpn.StaffID, CouponValue, GamingDate, GamingSession,  s.LastName , s.FirstName, cpn.SoldFromMachineID, cpn.QuantitySold, 
  0.00,		--Merchandise    
  0.00,		--Paper
  0.0,		--PaperSalesFloor
  0.0,		--PaperSalesTotal
  0.00,     --Electronic
  0.00,		--Credit
  0.00,		--Discount
  sum(cpn.NetSales),--Coupon
  0.00,		--Other
  0.00,		--Bingo Payouts
  0.00,		--Pulltabs
  cpn.GamingSession
  
  from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session) cpn
  join Staff s on cpn.StaffID = s.StaffID 
 Group by  CouponName, cpn.StaffID, CouponValue, GamingDate, GamingSession,  s.LastName , s.FirstName, cpn.SoldFromMachineID, cpn.QuantitySold 
      
        
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )          
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731      
      
      
      
--C       
--Insert Electronic Rows        
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
 AND (rdi.ProductTypeID = 14 and RDI.ProductItemName LIKE 'Discount%')      
 And (@Session = 0 or sp.GamingSession = @Session)      
 and rd.VoidedRegisterReceiptID IS NULL      
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, dt.DiscountTypeName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, dt.DiscountTypeName,       
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )          
GROUP BY rr.OperatorID, dt.DiscountTypeName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;      
      
      
-- END FIX DE8480,8481      
--K       
      
      
      
      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
  rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName , s.FirstName,       -- DE7731      
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
 AND (rdi.ProductTypeID IN (/*6: Bingo other not adding*/ 8, 9, 15) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' )) -- bjs 5/24/11 exclude pulltabs      
 And (@Session = 0 or sp.GamingSession = @Session)      
 and rd.VoidedRegisterReceiptID IS NULL      
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )          
      and ProductTypeID = 14       
      --and BarCode is null --DE10564:kc:8/6/2012      
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
SELECT rr.OperatorID, rdi.ProductItemName,       
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
 AND (rdi.ProductTypeID IN (/*6,*/ 8, 9, 15) or ( rdi.ProductTypeID = 14 AND RDI.ProductItemName NOT LIKE 'Discount%' )) -- bjs 5/24/11 exclude pulltabs      
 And (@Session = 0 or sp.GamingSession = @Session)      
 and rd.VoidedRegisterReceiptID IS NULL      
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID  )          
GROUP BY rr.OperatorID, rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID,sp.SessionPlayedID;         -- DE7731      
      
       
      
      
      
---- DEBUG      
      
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
SELECT rr.OperatorID, rr.GamingDate,      
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rr.GamingDate,      
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID,      
    rr.GamingDate,      
 ISNULL(convert(int, sp.GamingSession), -1),  -- 2011.07.22 bjs: allow for all-day n/a sessions      
    s.StaffID, s.LastName, s.FirstName,      
 rr.SoldFromMachineID,      
 SUM(rd.SalesTaxAmt * rd.Quantity)  -- DE8480      
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
SELECT rr.OperatorID, rr.GamingDate,      
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
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
--Cash payouts at the game level for payouttransbingogame      
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
      
--R      
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
--Cash payouts at the session level for payouttransbingogame      
select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  ptdc.DefaultAmount, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailCash ptdc      
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID      
 left join PayoutTransBingoGame ptb on ptdc.PayoutTransID = ptb.PayoutTransID      
 join SessionPlayed sp on ptb.SessionPlayedID = sp.SessionPlayedID      
 join Staff ss on pt.StaffID = ss.StaffID      
 where pt.OperatorID = @OperatorID      
 and (@StaffID = 0 or pt.StaffID = @StaffID )      
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
 and (@Session = 0 or sp.GamingSession = @Session)      
 and (@MachineID = 0 or pt.MachineID = @MachineID)      
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc       
  ;       
      
      
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
--Inventory game level payouts      
select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0.0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailMerchandise ptdc      
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
  and ptdc.IsPrimary = 1      
  ;       
        
  --T      
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
      
--Inventory session level payouts      
select pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0.0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailMerchandise ptdc      
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID      
 left join PayoutTransBingoGame ptb on ptdc.PayoutTransID = ptb.PayoutTransID      
 join SessionPlayed sp on ptb.SessionPlayedID = sp.SessionPlayedID      
 join Staff ss on pt.StaffID = ss.StaffID      
 where pt.OperatorID = @OperatorID      
 and (@StaffID = 0 or pt.StaffID = @StaffID )      
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
 and (@Session = 0 or sp.GamingSession = @Session)      
 and (@MachineID = 0 or pt.MachineID = @MachineID)      
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc       
  and ptdc.IsPrimary = 1      
  ;       
        
 --U      
 --Check payouts at the game level for payouttransbingogame      
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
--      
select       
      
 pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailCheck ptdc      
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
  and pt.PayoutTransID not in (select pt.PayoutTransID       
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
  and pt.AccrualTransID is null )      
      
        
--V      
--prize fees for checks at the session level from payouttransbingogame      
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
      
select       
      
 pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailCheck ptdc      
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID      
 left join PayoutTransBingoGame ptb on ptdc.PayoutTransID = ptb.PayoutTransID      
 join SessionPlayed sp on ptb.SessionPlayedID = sp.SessionPlayedID      
 join Staff ss on pt.StaffID = ss.StaffID      
       
 where pt.OperatorID = @OperatorID      
 and (@StaffID = 0 or pt.StaffID = @StaffID )      
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
 and (@Session = 0 or sp.GamingSession = @Session)      
 and (@MachineID = 0 or pt.MachineID = @MachineID)      
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc       
  and pt.PayoutTransID not in (select pt.PayoutTransID       
from PayoutTransDetailCash ptdc      
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID      
 left join PayoutTransBingoGame ptb on ptdc.PayoutTransID = ptb.PayoutTransID      
 join SessionPlayed sp on ptb.SessionPlayedID = sp.SessionPlayedID      
 join Staff ss on pt.StaffID = ss.StaffID      
 where pt.OperatorID = @OperatorID      
 and (@StaffID = 0 or pt.StaffID = @StaffID )      
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
 and (@Session = 0 or sp.GamingSession = @Session)      
 and (@MachineID = 0 or pt.MachineID = @MachineID)      
  and pt.voidtransid is null      
  and pt.AccrualTransID is null )      
      
--W      
--prize fees for checks for payouttransbingocustom at the game level      
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
      
select       
      
 pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailCheck ptdc      
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
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc       
  and pt.PayoutTransID not in (select pt.PayoutTransID       
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
  and pt.voidtransid is null      
  and pt.AccrualTransID is null )      
      
        
--X      
--prize fees for checks at the session level from payouttransbingocustom      
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
      
select       
      
 pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailCheck ptdc      
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID      
 left join PayoutTransBingoCustom ptb on ptdc.PayoutTransID = ptb.PayoutTransID      
 join SessionPlayed sp on ptb.SessionPlayedID = sp.SessionPlayedID      
 join Staff ss on pt.StaffID = ss.StaffID      
       
 where pt.OperatorID = @OperatorID      
 and (@StaffID = 0 or pt.StaffID = @StaffID )      
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
 and (@Session = 0 or sp.GamingSession = @Session)      
 and (@MachineID = 0 or pt.MachineID = @MachineID)      
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc       
  and pt.PayoutTransID not in (select pt.PayoutTransID       
from PayoutTransDetailCash ptdc      
join PayoutTrans pt on ptdc.PayoutTransID = pt.PayoutTransID      
 left join PayoutTransBingoCustom ptb on ptdc.PayoutTransID = ptb.PayoutTransID      
 join SessionPlayed sp on ptb.SessionPlayedID = sp.SessionPlayedID      
 join Staff ss on pt.StaffID = ss.StaffID      
 where pt.OperatorID = @OperatorID      
 and (@StaffID = 0 or pt.StaffID = @StaffID )      
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
 and (@Session = 0 or sp.GamingSession = @Session)      
 and (@MachineID = 0 or pt.MachineID = @MachineID)      
  and pt.voidtransid is null      
  and pt.AccrualTransID is null )      
      
--Y Check payouts at the game level for good neighbor for prize fees      
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
--      
select       
      
 pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailCheck ptdc      
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
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc       
  and pt.PayoutTransID not in (select pt.PayoutTransID       
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
  and pt.voidtransid is null      
  and pt.AccrualTransID is null )      
        
--Z      
--Check payouts at the game level for royalty payouts      
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
--      
select       
      
 pt.OperatorID,pt.GamingDate,sp.GamingSession,pt.StaffID      
      ,ss.LastName, ss.FirstName,  0, pt.PrizeFee, sp.SessionPlayedID      
from PayoutTransDetailCheck ptdc      
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
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc         
  and pt.PayoutTransID not in (select pt.PayoutTransID       
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
  and pt.voidtransid is null      
  and pt.AccrualTransID is null )      
        
        
      
 --AA       
 --PayoutTransBingoCustom game level cash      
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
      
--AB      
--payouttransbingocustom session level cash payouts      
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
 join SessionPlayed sp on ptb.SessionPlayedID = sp.SessionPlayedID      
 join Staff ss on pt.StaffID = ss.StaffID      
 where pt.OperatorID = @OperatorID      
 and (@StaffID = 0 or pt.StaffID = @StaffID )      
 and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
 and (@Session = 0 or sp.GamingSession = @Session)      
 and (@MachineID = 0 or pt.MachineID = @MachineID)      
  and pt.voidtransid is null      
  and pt.AccrualTransID is null --7/3/2012 DE10561 kc       
  ;       
      
  --AC       
  --Good neighbor cash payouts at the game level      
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
        
        
        
  --AD       
 --PayoutTransBingoRoyalty cash payouts at the game level      
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
      
      
      
--AE      
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
      
      
--8.13.2012 payout progressive by check added      
--AF      
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
)select   pt.OperatorID      
        ,pt.GamingDate      
        ,sp.GamingSession      
        ,pt.StaffID      
        ,ss.LastName      
        ,ss.FirstName      
      /*  ,ISNULL(ptdc.DefaultAmount, 0.00)*/,0.00      
        ,pt.PrizeFee      
        ,sp.SessionPlayedID      
from AccrualTransactionDetails atd      
    join PayoutTrans pt on atd.AccrualTransactionId = pt.AccrualTransID      
    join AccrualTransactions at on pt.AccrualTransId = at.AccrualTransactionId       
    join SessionPlayed sp on at.SessionPlayedID = sp.SessionPlayedID      
    join Staff ss on pt.StaffID = ss.StaffID      
   /* join PayoutTransDetailCash ptdc on pt.PayoutTransID = ptdc.PayoutTransID*/      
    join  PayoutTransDetailCheck ptdc on ptdc.PayoutTransID = pt.PayoutTransID       
 where pt.OperatorID = @OperatorID      
    and (@StaffID = 0 or pt.StaffID = @StaffID)      
    and (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate)      
    and (@Session = 0 or sp.GamingSession = @Session)      
    and (@MachineID = 0 or pt.MachineID = @MachineID)      
    and pt.voidtransid is null      
    and pt.PayoutTransID not in(select  pt.PayoutTransID       
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
    and pt.voidtransid is null )       
      
-------------------------------------------------------      
-- Banks      
-------------------------------------------------------      
      
-- FIX DE8853      
-- Money Center mode have true Master and Staff Banks.  Show only staff banks here (original code).      
if(@CashMethod = 3)      
begin      
--AG = 3      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
  case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,      
        s.StaffID, s.LastName , s.FirstName,      
        b.bkMachineID,
        case b.bkBankTypeID when 1 then 0 else				--US3735
			SUM(ISNULL(ctd.ctrdDefaultTotal, 0)) End     
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
-- AND b.bkBankTypeID = 2      -- US3735
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID, b.bkBankTypeID /* US3735 */;      
--AH = 0      
-- Get banks issued from our staff member      
    
  --DEBUG please delete after    
--    select *  
--    FROM CashTransaction ct      
-- JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)      
-- JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)      
-- JOIN Staff s ON (s.StaffID = b.bkStaffID)      
--WHERE b.bkStaffID <> 0 -- Looking for Staff Banks      
-- AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks      
-- AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.      
-- AND ct.ctrTransactionTypeID IN (11/*,17*/) -- Issues Only      
-- AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range      
-- AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range      
-- AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided      
--    and (@StaffID = 0 or b.bkStaffID = @StaffID)      
--    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )          
-- and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))      
 --AND b.bkBankTypeID = 2   
--END DEBUG  
      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
  case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,      
        s.StaffID, s.LastName , s.FirstName,      
        b.bkMachineId,     
        case b.bkBankTypeID when 1 then 0 else      -- US3735
			SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0))  End    
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
-- AND b.bkBankTypeID = 2      -- US3735 
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID, b.bkBankTypeID /* US3735 */;      
--AI= 0      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
  case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,      
        s.StaffID, s.LastName , s.FirstName,      
        b.bkMachineID,
        case b.bkBankTypeID when 1 then 0 else           -- US3735
		 SUM(ISNULL(ctd.ctrdDefaultTotal, 0)) End   
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
-- AND b.bkBankTypeID = 2		-- US3735      
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID, b.bkBankTypeID /* US3735 */;      
--AJ = 3      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
  case ct.ctrGamingSession when 0 then -1 else ct.ctrGamingSession end,      
        s.StaffID, s.LastName , s.FirstName,      
        b.bkMachineID,  
        case b.bkBankTypeID when 1 then 0 else	-- US3735       
			SUM(ISNULL(ctd.ctrdDefaultTotal * -1, 0)) End     
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
-- AND b.bkBankTypeID = 2		-- US3735
GROUP BY b.bkOperatorID, ct.ctrGamingDate, ct.ctrGamingSession, s.StaffID, s.LastName, s.FirstName, b.bkMachineID, b.bkBankTypeID /* US3735 */;        
      
end      
else if(@CashMethod = 1)   -- POS mode      
begin      
-- POS Mode has banks, no drops      
      
--AK      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
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
      
      
--AL      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
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
      
--AM      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
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
      
      
--AN      
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
SELECT b.bkOperatorID, ct.ctrGamingDate,      
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
      
end; -- END MACHINE MODE      
      
      
      
---- debug      
      
--return;      
      
--      
-- Paper sales: both register sales and inventory (floor sales)      
--       
--AO = 18      
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
    (@CashMethod <> 2 and (@StaffID = 0 or s.StaffID = @StaffID))    -- Machine Mode must print activity for all staff      
     or ((@CashMethod = 2 and @MachineID = 0 or fps.soldFromMachineId = @MachineID)       
     or (@CashMethod = 2 and ISNULL(fps.soldFromMachineId,-1) = -1))       
      
      
---- Calculate our row totals      
--UPDATE @ClosingResults      
--set paperSalesTotal = (paper + paperSalesFloor);      
      
declare @ResultSet table      
(      
 opId    int,      
 staffId             int,            -- DE7731      
 gamingDate          datetime,       -- DE7731      
 sessionNbr          int,            -- DE7731      
 LastName            NVARCHAR(64),      
 FirstName           NVARCHAR(64),      
 soldFromMachineId   int,      
 electronic   MONEY,      
 paper    money,      
 merchandise   money,      
 discount   MONEY,  
 coupon   MONEY,    
 other    MONEY,      
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
)     
      
     
-- HACK to overcome problem with empty rows in crystal report      
--AP = 0      
;with RESULTS(    --Transfer all data from @ClosingResult into @ResultSet  
  opId      
, staffId, gamingDate, sessionNbr, LastName, FirstName      
, soldFromMachineId      
, electronic      
, paper      
, merchandise      
, discount, coupon,  other, cashPayout, pullTabPayouts, pullTabSales      
, taxes, fees, TotalBanks, TotalDrop, TotalDue, OverShort,sessionPlayedId      
, progressivePayouts, prizeFees)      
as      
(SELECT       
   opId      
    , staffIdNbr [staffId]      
    , gamingDate      
 , isnull(sessionNbr, -1)  [sessionNbr]   -- 2011.07.22 bjs: allow for day-long, N/A sessions      
    , stafflastName [LastName]      
    , staffFirstName [FirstName]      
    , isnull(soldFromMachineId, 0) [soldFromMachineId]      
 , SUM(isnull(electronic, 0)) [electronic]      
       
 , sum(isnull(paperSalesTotal, 0)) [paper]      
 , sum(isnull(merchandise, 0)) [merchandise]      
       
 , SUM(isnull(discount, 0)) [discount]   
 , SUM(isnull(coupon, 0)) [discount]       
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
, discount, coupon, other, cashPayout, pullTabPayouts, pullTabSales      
, taxes, fees, TotalBanks, TotalDrop, TotalDue, OverShort,sessionPlayedId      
, ProgressivePayouts, PrizeFees      
from RESULTS      
where    (@StaffID = 0 or staffId = @StaffID or @CashMethod = 2)  -- Machine Mode must print activity for all staff      
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
      
--return;      
      
      
      
--AQ = 0      
;with NOBLANKROWS      
(      
 opId, cashMethodId      
  , staffId, gamingDate, sessionNbr, LastName, FirstName, soldFromMachineId      
  , electronic      
  , paper      
  , merchandise      
  , discount 
  , coupon  
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
  , discount , coupon
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
, discount,  coupon, other,cashPayout, pullTabPayouts, pullTabSales, taxes,          
fees = case       
when @Session = 2 and sessionNbr = 1 then 0.00       
when @Session = 1 and sessionNbr = 2 then 0.00      
else fees      
end      
, TotalBanks, TotalDrop, TotalDue, OverShort,sessionPlayedID,ProgressivePayouts, PrizeFees  into #a    --Transfer all data from @ResultSet to temp table #a
from NOBLANKROWS      
where (sessionNbr = @Session or @Session = 0)      
--where Checker <> 0    -- restore this if needed to filter out blank rows!      
ORDER BY staffId, gamingDate, sessionNbr;      
    
   ------------------------------
   
-- 2013-11-06 bjs: change CTE name to a non-reserved word.
-- 2013.12.24 jkn: DE11488 This CTE was renamed but the other uses of it were not

;with result1 as --#b  
(   
 -- DE11719 a distinct select clears up the issue with mulitiple banks being returned and causing
 --  issues with calculations
 Select distinct b.bkStaffID, b.bkGamingDate, b.BkGamingSession,b.bkBankTypeID, ct.ctrTransactionStaffID     
 FROM CashTransaction ct      
 JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)      
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)      
 JOIN Staff s ON (s.StaffID = b.bkStaffID)      
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks      
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks      
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.      
 AND ct.ctrTransactionTypeID IN (11/*,17*/) -- Issues Only      
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range      
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range      
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided      
    and (@StaffID = 0 or b.bkStaffID = @StaffID)      
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )          
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))      
 AND b.bkBankTypeID = 1   )    
,result2 as --#TestA  
(  
 Select b.bkStaffID, b.bkGamingDate, b.BkGamingSession,b.bkBankTypeID, ct.ctrTransactionStaffID   
 FROM CashTransaction ct      
 JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)      
 JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)      
 JOIN Staff s ON (s.StaffID = b.bkStaffID)      
WHERE b.bkStaffID <> 0 -- Looking for Staff Banks      
 AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks      
 AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.      
 AND ct.ctrTransactionTypeID IN (11/*,17*/) -- Issues Only      
 AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range      
 AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range      
 AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided      
    and (@StaffID = 0 or b.bkStaffID = @StaffID)      
    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )          
 and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))      
) --AND b.bkBankTypeID = 1      
, result3 as--#TestB  
(  
   select distinct (BkStaffID), ctrTransactionStaffID  from result2 )  
,result4 as --#c  
(  
 select a.*, isnull(x.TotalDue2,0) TotalDue2, isnull(x.Overshort2,0) overshort2     
 --into #c    
 from #a a    
left join (    
select staffID, SessionNbr, gamingdate,     
sum(Paper) +    
sum(Electronic) +    
Sum(Other) +    
sum(Merchandise) +    
sum(pullTabSales) +    
sum(discount) +    
sum(taxes) +    
sum(fees) +    
sum(prizeFees) +    
sum(TotalBanks) +    
(-1 * sum(Cashpayout))+    
(-1 * sum(ProgressivePayouts)) /*TotalDue2*/
--ADDED + overshort
+
 -1 * ((sum(Paper) +    
sum(Electronic) +    
Sum(Other) +    
sum(Merchandise) +    
sum(pullTabSales) +    
sum(discount) +    
sum(taxes) +    
sum(fees) +    
sum(prizeFees) +    
sum(TotalBanks) +    
(-1 * sum(Cashpayout))+    
(-1 * sum(ProgressivePayouts))) +    
sum(TotalDrop)) TotalDue2

,  
sum(TotalDrop) TotalDrop,    
  -1 * ((sum(Paper) +    
sum(Electronic) +    
Sum(Other) +    
sum(Merchandise) +    
sum(pullTabSales) +    
sum(discount) +    
sum(coupon) +
sum(taxes) +    
sum(fees) +    
sum(prizeFees) +    
sum(TotalBanks) +    
(-1 * sum(Cashpayout))+    
(-1 * sum(ProgressivePayouts))) +    
sum(TotalDrop)) overshort2 , sum(TotalBanks) TotalBanks   
from #a    
group by  staffID, SessionNbr, gamingdate)x on     
x.totaldrop = a.totaldrop --this is enough     
and x.gamingdate = a.gamingdate    
and x.staffID = a.staffID    
and x.SessionNbr = a.SessionNbr    
and x.TotalBanks = a.Totalbanks  
--where a.sessionplayedID is not null  
--ORDER BY a.staffId, a.gamingDate, a.sessionNbr;      
  )  
,result5 as --#d  
(  
 select c.*, isnull(b.bkBankTypeID,2) BankTypeID, ctrTransactionStaffID  from result4  c left join result1 b  --DE11488
 on b.bkStaffID = c.staffID    
 and b.BkgamingSession = c.sessionNbr    
 and b.BkGamingDate = c.gamingDate  )  
,result6 as --#TestC  
(    
select d.*, a.ctrTransactionStaffID ctrTheOne  from result5 d join result3 a on a.bkStaffID = d.staffId    
)select * into #TestC from result6;  --Tranfer all data into #TestC
  
 drop Table #a    
     
  update #TestC    
 set TotalBanks = TotalBanks + x.TotalDue2    
 from #TestC  d    
 inner join (  select sum(TotalDue2) Totaldue2,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
 group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
 on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
 and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
 and x.ctrTheOne = d.ctrTheOne   
 where d.TotalBanks <> 0.00    
     
     
update #TestC    
set TotalDue2 = TotalDue2 + x.TotalDue3 --/*added*/- overshort2       
 from #TestC  d    
 inner join (  select sum(TotalDue2) Totaldue3,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
 group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
 on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
 and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
 and x.ctrTheOne = d.ctrTheOne   
 where d.TotalBanks <> 0.00    
 
 /*adding to solve per Staff*/
-- update #TestC    
--set TotalDue2 = TotalDue2 + x.TotalDue3 /*added*/- overshort2       
-- from #TestC  d    
-- inner join (  select sum(TotalDue2) Totaldue3,gamingDate, SessionNbr, 2 BankTypeID, ctrTheOne    from #TestC  where BankTypeID =  2    
-- group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
-- on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
-- and x.ctrTheOne = d.ctrTheOne   
-- where d.TotalBanks <> 0.00    
 
 --select sum(TotalDue2) Totaldue3,gamingDate, SessionNbr, 2 BankTypeID, ctrTheOne    from #TestC  where BankTypeID =  2    
 --group by gamingDate, SessionNbr, BankTypeID, ctrTheOne
 
     
     --select * from #TestC 
     
 --update #d     
 --set TotalDrop = TotalDrop + x.TotalDrop2    
 --from #d d    
 --inner join (  select sum(TotalDrop) TotalDrop2,gamingDate, SessionNbr, 1 BankTypeID  from #d where BankTypeID <> 1    
 --group by gamingDate, SessionNbr, BankTypeID) x    
 --on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
 --and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00    
 --where d.TotalBanks <> 0.00    
     
update #TestC    
set TotalDrop = TotalDrop + x.TotalDrop2 
 from #TestC  d    
 inner join (  select sum(TotalDrop) TotalDrop2,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
 group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
 on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
 and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
 and x.ctrTheOne = d.ctrTheOne   
 where d.TotalBanks <> 0.00    
  
  
     
 -- update #d     
 --set OverShort2 = OverShort2 + x.OverShort3    
 --from #d d    
 --inner join (  select sum(OverShort2) OverShort3,gamingDate, SessionNbr, 1 BankTypeID  from #d where BankTypeID <> 1    
 --group by gamingDate, SessionNbr, BankTypeID) x    
 --on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
 --and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00    
 --where d.TotalBanks <> 0.00    
     
    
     
--           update #TestC    
--set OverShort2 = OverShort2 + x.OverShort3    
-- from #TestC  d    
-- inner join (  select sum(OverShort2) OverShort3,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
-- group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
-- on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
-- and x.ctrTheOne = d.ctrTheOne   
-- where d.TotalBanks <> 0.00    
     
  
   select OperatorID  
   ,cashMethodId
   ,staffId
   ,gamingDate
   ,sessionNbr
   ,LastName
   ,FirstName
   ,soldFromMachineId
   ,electronic 
   ,paper
   ,merchandise
   ,discount
   ,coupon
   ,other 
   ,cashPayout
   ,pullTabPayouts
   ,pullTabSales 
   ,taxes
   ,fees
   ,TotalBanks
   ,TotalDrop
   ,TotalDue
   ,OverShort
   ,sessionPlayedID
   ,ProgressivePayouts
   ,PrizeFees 
   ,TotalDue2 - overshort2 as TotalDue2
   ,overshort2
   ,BankTypeID
   ,ctrTransactionStaffID
   ,ctrTheOne                      
   from #TestC  
   where (StaffID = @StaffID2 or @StaffID2 = 0) 
    

drop Table #TestC   
  ------------------------------------------------------------
---------------------FOR DEBUGGING--------------------- 
----------------------USING TEMP TABLE-------------------------- 
---- 1/30/2013 (knc)  
--Select b.bkStaffID, b.bkGamingDate, b.BkGamingSession,b.bkBankTypeID, ct.ctrTransactionStaffID  into #b    
-- FROM CashTransaction ct      
-- JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)      
-- JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)      
-- JOIN Staff s ON (s.StaffID = b.bkStaffID)      
--WHERE b.bkStaffID <> 0 -- Looking for Staff Banks      
-- AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks      
-- AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.      
-- AND ct.ctrTransactionTypeID IN (11/*,17*/) -- Issues Only      
-- AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range      
-- AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range      
-- AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided      
--    and (@StaffID = 0 or b.bkStaffID = @StaffID)      
--    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )          
-- and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))      
-- AND b.bkBankTypeID = 1      
     
----select * from #b  
  
-- Select b.bkStaffID, b.bkGamingDate, b.BkGamingSession,b.bkBankTypeID, ct.ctrTransactionStaffID  into #TestA   
-- FROM CashTransaction ct      
-- JOIN Bank b ON (ct.ctrDestBankID = b.bkBankID)      
-- JOIN CashTransactionDetail ctd ON (ct.ctrCashTransactionID = ctd.ctrdCashTransactionID)      
-- JOIN Staff s ON (s.StaffID = b.bkStaffID)      
--WHERE b.bkStaffID <> 0 -- Looking for Staff Banks      
-- AND b.bkStaffID IS NOT NULL -- Looking for Staff Banks      
-- AND b.bkOperatorID = @OperatorID -- DE7244 - Only include the specified operator's banks.      
-- AND ct.ctrTransactionTypeID IN (11/*,17*/) -- Issues Only      
-- AND ct.ctrGamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) -- Our Date Range      
-- AND ct.ctrGamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) -- Our Date Range      
-- AND NOT EXISTS (SELECT * FROM CashTransaction ct2 WHERE ct2.ctrOriginalCashTransactionID = ct.ctrCashTransactionID) -- Not Voided      
--    and (@StaffID = 0 or b.bkStaffID = @StaffID)      
--    -- and (@MachineID = 0 or b.bkMachineID = @MachineID )          
-- and (@Session = 0 or (ct.ctrGamingSession = @Session or ct.ctrGamingSession = 0 ))      
-- --AND b.bkBankTypeID = 1      
     
--   --select * from #TestA   
     
--   select distinct (BkStaffID), ctrTransactionStaffID  into #TestB from #TestA   
  

  
-- select a.*, isnull(x.TotalDue2,0) TotalDue2, isnull(x.Overshort2,0) overshort2     
-- into #c    
-- from #a a    
--left join (    
--select staffID, SessionNbr, gamingdate,     
--sum(Paper) +    
--sum(Electronic) +    
--Sum(Other) +    
--sum(Merchandise) +    
--sum(pullTabSales) +    
--sum(discount) +    
--sum(taxes) +    
--sum(fees) +    
--sum(prizeFees) +    
--sum(TotalBanks) +    
--(-1 * sum(Cashpayout))+    
--(-1 * sum(ProgressivePayouts)) /*TotalDue2*/
----ADDED + overshort
--+
-- -1 * ((sum(Paper) +    
--sum(Electronic) +    
--Sum(Other) +    
--sum(Merchandise) +    
--sum(pullTabSales) +    
--sum(discount) +    
--sum(taxes) +    
--sum(fees) +    
--sum(prizeFees) +    
--sum(TotalBanks) +    
--(-1 * sum(Cashpayout))+    
--(-1 * sum(ProgressivePayouts))) +    
--sum(TotalDrop)) TotalDue2

--,
--sum(TotalDrop) TotalDrop,    
    
-- -1 * ((sum(Paper) +    
--sum(Electronic) +    
--Sum(Other) +    
--sum(Merchandise) +    
--sum(pullTabSales) +    
--sum(discount) +    
--sum(taxes) +    
--sum(fees) +    
--sum(prizeFees) +    
--sum(TotalBanks) +    
--(-1 * sum(Cashpayout))+    
--(-1 * sum(ProgressivePayouts))) +    
--sum(TotalDrop)) overshort2 , sum(TotalBanks) TotalBanks   
--from #a    
--group by  staffID, SessionNbr, gamingdate)x on     
--x.totaldrop = a.totaldrop --this is enough     
--and x.gamingdate = a.gamingdate    
--and x.staffID = a.staffID    
--and x.SessionNbr = a.SessionNbr    
--and x.TotalBanks = a.Totalbanks  
----where a.sessionplayedID is not null  
--ORDER BY a.staffId, a.gamingDate, a.sessionNbr;  
    
  
  
-- select c.*, isnull(b.bkBankTypeID,2) BankTypeID, ctrTransactionStaffID  into #d from #c c left join #b b     
-- on b.bkStaffID = c.staffID    
-- and b.BkgamingSession = c.sessionNbr    
-- and b.BkGamingDate = c.gamingDate    
     
--select d.*, a.ctrTransactionStaffID ctrTheOne into #TestC from #d d join #TestB a on a.bkStaffID = d.staffId    
----16 rows  
  
  
     
-- --select sum(TotalDue2),gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
-- --group by gamingDate, SessionNbr, BankTypeID, ctrTheOne  
-- --select * from #d    
     
  
----select * from #d   
     
  
     
-- --update #d    
-- --set TotalBanks = TotalBanks + x.TotalDue2    
-- --from #d d    
-- --inner join ( select sum(TotalDue2) TotalDue2,gamingDate, SessionNbr, 1 BankTypeID  from #d where BankTypeID <> 1    
-- --group by gamingDate, SessionNbr, BankTypeID ) x    
-- --on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- --and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00    
-- --where d.TotalBanks <> 0.00    
     
--    update #TestC    
-- set TotalBanks = TotalBanks + x.TotalDue2    
-- from #TestC  d    
-- inner join (  select sum(TotalDue2) Totaldue2,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
-- group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
-- on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
-- and x.ctrTheOne = d.ctrTheOne   
-- where d.TotalBanks <> 0.00    
     
  
     
-- --update #d     
-- --set TotalDue2 = TotalDue2 + x.TotalDue3    
-- --from #d d    
-- --inner join ( select sum(TotalDue2) TotalDue3,gamingDate, SessionNbr, 1 BankTypeID  from #d where BankTypeID <> 1    
-- --group by gamingDate, SessionNbr, BankTypeID ) x    
-- --on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- --and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00    
-- --where d.TotalBanks <> 0.00    
     
--     update #TestC    
--set TotalDue2 = TotalDue2 + x.TotalDue3    
-- from #TestC  d    
-- inner join (  select sum(TotalDue2) Totaldue3,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
-- group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
-- on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
-- and x.ctrTheOne = d.ctrTheOne   
-- where d.TotalBanks <> 0.00    
     
  
    
     
-- --update #d     
-- --set TotalDrop = TotalDrop + x.TotalDrop2    
-- --from #d d    
-- --inner join (  select sum(TotalDrop) TotalDrop2,gamingDate, SessionNbr, 1 BankTypeID  from #d where BankTypeID <> 1    
-- --group by gamingDate, SessionNbr, BankTypeID) x    
-- --on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- --and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00    
-- --where d.TotalBanks <> 0.00    
     
--        update #TestC    
--set TotalDrop = TotalDrop + x.TotalDrop2    
-- from #TestC  d    
-- inner join (  select sum(TotalDrop) TotalDrop2,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
-- group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
-- on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
-- and x.ctrTheOne = d.ctrTheOne   
-- where d.TotalBanks <> 0.00    
  
  
     
-- -- update #d     
-- --set OverShort2 = OverShort2 + x.OverShort3    
-- --from #d d    
-- --inner join (  select sum(OverShort2) OverShort3,gamingDate, SessionNbr, 1 BankTypeID  from #d where BankTypeID <> 1    
-- --group by gamingDate, SessionNbr, BankTypeID) x    
-- --on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- --and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00    
-- --where d.TotalBanks <> 0.00    
     
    
     
--           update #TestC    
--set OverShort2 = OverShort2 + x.OverShort3    
-- from #TestC  d    
-- inner join (  select sum(OverShort2) OverShort3,gamingDate, SessionNbr, 1 BankTypeID, ctrTheOne    from #TestC  where BankTypeID <> 1    
-- group by gamingDate, SessionNbr, BankTypeID, ctrTheOne ) x    
-- on x.GamingDate = d.gamingDate and x.sessionNbr = d.SessionNbr    
-- and x.BankTypeID = d.BankTypeID and d.BankTypeID <> 0.00  
-- and x.ctrTheOne = d.ctrTheOne   
-- where d.TotalBanks <> 0.00    
     
-- --select * from #d    
--   select * from #TestC   
    
     
--drop table #a    
--drop table #b    
--drop table #c    
--drop table #d    
  
--drop table #TestA   
--drop Table #TestB   
--drop Table #TestC   
-----------------------------------------------------     
END      


GO

