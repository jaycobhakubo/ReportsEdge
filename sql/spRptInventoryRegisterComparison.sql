USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryRegisterComparison]    Script Date: 02/07/2014 15:57:13 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryRegisterComparison]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryRegisterComparison]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryRegisterComparison]    Script Date: 02/07/2014 15:57:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE  [dbo].[spRptInventoryRegisterComparison] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Compares register sales to inventory sales for Paper, Pull Tabs, Bingo and MSDE products.
--               Sales source is ignored to report on all products.
--				 Logic is copied from spRptRegisterClosingReportRegister>
-- =============================================
	@OperatorID		AS INT,
	@StartDate		AS DATETIME,  
	@EndDate		AS DATETIME,  
	@Session		AS INT

AS
	
SET NOCOUNT ON


--TEST
--declare   
--@OperatorID    AS INT,    
--@StartDate     AS DATETIME,  
--@EndDate       AS DATETIME,  
--@Session       AS INT

--set @OperatorID = 1
--set @StartDate = '1/1/2013 00:00:00'
--set @EndDate = '1/31/2014 00:00:00'
--set @Session = 0
--END TEST

-- Verfify POS sending valid values  
set @Session = isnull(@Session, 0);  
  
  
DECLARE @Inventory TABLE  
(  
	ItemName        VARCHAR(100),
	Counts			Int,
	CountValue      money
);  
  
DECLARE @Tab TABLE  
(  
	GamingDate      datetime,  
	GamingSession   int ,  
	Price           money,  
	Counts          INT,
	ItemID			Int,  
	ItemName        VARCHAR(100),
	ProductGroup	nvarchar(64),
	ProductTypeID   Int,
	SalesSourceID	INT,  
	MasterTransID	int  
 );  
--- Insert inventory transactions  
INSERT INTO @Tab  
select  
    ivtGamingDate,   
    ivtGamingSession,   
    ivtPrice,       
    ( CASE ivtTransactionTypeID WHEN 23 THEN ivdDelta ELSE 0 END) +  
    ( CASE ivtTransactionTypeID WHEN 25 THEN ivdDelta ELSE 0 END) +  
    ( CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END) +  
    ( CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END),  
    pri.ProductItemID,
    pri.ItemName,
    pg.GroupName,
    pri.ProductTypeID,
    pri.SalesSourceID,   
 case when ivtMasterTransactionID is null then ivtInvTransactionID else ivtMasterTransactionID end
from InventoryItem   
join InvTransaction on iiInventoryItemID = ivtInventoryItemID  
join InvTransactionDetail on ivtInvTransactionID = ivdInvTransactionID  
join InvLocations on ivdInvLocationID = ilInvLocationID  
left join IssueNames on ivtIssueNameID = inIssueNameID  
left join ProductItem pri on pri.ProductItemID = iiProductItemID  
left join ProductType pt on pri.ProductTypeID = pt.ProductTypeID
left join ProductGroup pg on pri.ProductGroupID = pg.ProductGroupID         
where (ilMachineID <> 0 or ilStaffID <> 0)  
and (ivtGamingDate >= @StartDate and ivtGamingDate <= @EndDate)  
and (ivtGamingSession = @Session or @Session = 0)  
and pri.OperatorID = @OperatorID  

INSERT INTO @Inventory  
(
	ItemName,
	Counts,
	CountValue
)    
SELECT	
		ItemName,
		SUM(Counts),
		SUM(Counts * Price)    
FROM @Tab   
Group By ItemName
Order By ItemName;

      
----------------------------------------------------------------    
DECLARE @RegisterSales TABLE   
(  
	ItemName            VARCHAR(100),
	Counts				Int,
	CountValue1         money  
);  
     
INSERT INTO @RegisterSales  
select   
    rdi.ProductItemName,
    Sum(rd.Quantity * rdi.Qty),
    SUM(rd.Quantity * rdi.Qty * rdi.Price)   
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)  
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 1  
 and rr.OperatorID = @OperatorID     
 AND rdi.ProductTypeID in (7, 16, 17) -- Merchandise, Paper, Pull Tab
 And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL   
GROUP BY rdi.ProductItemName
  
-- Deduct returns  
INSERT INTO @RegisterSales  
SELECT  
    rdi.ProductItemName,
    SUM(-1 * (rd.Quantity * rdi.Qty)),
	SUM(-1 * rd.Quantity * rdi.Qty * rdi.Price)    
FROM RegisterReceipt rr  
 JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
 JOIN RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
 LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)   
Where rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)  
 And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
 and rr.SaleSuccess = 1  
 and rr.TransactionTypeID = 3 -- Return  
 and rr.OperatorID = @OperatorID  
 AND rdi.ProductTypeID in (7, 16, 17) -- Merchandise, Paper, Pull Tab
 And (@Session = 0 or sp.GamingSession = @Session)  
 and rd.VoidedRegisterReceiptID IS NULL    
GROUP BY  rdi.ProductItemName
Order By rdi.ProductItemName  
		    
select   
  isnull(r.ItemName, i.ItemName) as ProductName,
  isnull(r.Counts, 0) as RegisterCount,
  isnull(r.CountValue1, 0) as RegisterValue,
  isnull(i.Counts, 0) as InvetoryCount,
  isnull(r.Counts, 0) - isnull(i.Counts, 0) as QtyDifference, 
  isnull(i.CountValue, 0) as InventoryValue,
  isnull(r.CountValue1, 0) - isnull(i.CountValue, 0) as AmountDifference  
from @RegisterSales r 
full outer join @Inventory i on r.ItemName = i.ItemName
--Full Outer Join @Inventory i on r.ItemName = i.ItemName
--And r.SalesSourceID = 1 and i.SalesSourceID = 1
Group By r.ItemName, i.ItemName, r.CountValue1, i.CountValue, r.Counts, i.Counts
order by ProductName

SET NOCOUNT OFF


GO

