USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptProgressiveSales]    Script Date: 2/27/2019 5:18:29 PM ******/
DROP PROCEDURE [dbo].[spRptProgressiveSales]
GO

/****** Object:  StoredProcedure [dbo].[spRptProgressiveSales]    Script Date: 2/27/2019 5:18:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-----------------------------------------------------------
--	Created By: FortuNet
--  Description: Returns the Progressive Sales
--	20160826 tmp: Progressive Sales report.
-----------------------------------------------------------


CREATE procedure [dbo].[spRptProgressiveSales] 
    @OperatorID int,
	@StartDate	datetime,
	@EndDate	datetime,
	@Session	int
as
begin

set nocount on;
   		
--set	@OperatorID = 1
--set	@GamingDate = '08/24/2016'
--set	@EndDate = '08/24/2016'
--set	@Session = 0

declare @Sales table    
(    
	productName			NVARCHAR(64),              
	Amount				money,
	gamingSession		int,
	gamingDate			datetime
 );    

declare @AccrualProducts table
(
	ProductItemID		int,
	ItemName			nvarchar(64)
)
insert into @AccrualProducts
(
	ProductItemID
	, ItemName
)
select	distinct(api.ProductItemID) as ProductItemID
		, p.ItemName
From	AccrualProductItems api join ProductItem p on api.ProductItemID = p.ProductItemID
   
 --      
 -- Insert sales with a sales source of register
 --    
insert into @Sales    
(    
	productName,
	amount,
	gamingSession,
	gamingDate
)    
select 	ap.ItemName, 
		case when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
				when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end,
		sp.GamingSession,
		rr.GamingDate
from	RegisterReceipt rr  
		join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)  
		left join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)  
		left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
		join @AccrualProducts ap on (rdi.ProductItemName = ap.ItemName)
where	rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
		and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
		and rr.SaleSuccess = 1  
		and ( rr.TransactionTypeID = 1 
			  or rr.TransactionTypeId = 3
			 ) -- Sale Or Returns  
		and rr.OperatorID = @OperatorID  
		and ( @Session = 0
			  or sp.GamingSession = @Session
			 )  
		and rd.VoidedRegisterReceiptID IS NULL		-- Do not include voided transactions
		and rdi.SalesSourceID = 2
group by rr.GamingDate, 
		sp.GamingSession, 
		ap.ItemName, 
		rr.TransactionTypeID;

-- Insert sales with a sales source of inventory.		
--
with FloorSales
(
	GamingDate
	, SessionNo
	, StaffID
	, ProdTypeID
	, GroupName
	, PackageName
	, ItemName
	, Price
	, ReturnCount
	, SkipCount
	, BonanzaCount
	, IssueCount
	, PlaybackCount
	, DamageCount
	, TransferCount
) as 
(
select	ivtGamingDate
		, ivtGamingSession
		, ilStaffID
		, item.ProductTypeID
		, pg.GroupName
		, 'Floor Sales' [PackageName]  -- req'd b/c no direct link between inventory transaction and packages
		, item.ItemName
		, ivtPrice
		, CASE ivtTransactionTypeID WHEN 3 THEN ivdDelta ELSE 0 END     [ReturnsCount]
		, CASE ivtTransactionTypeID WHEN 23 THEN ivdDelta ELSE 0 END    [SkipCount]
		, CASE ivtTransactionTypeID WHEN 24 THEN ivdDelta ELSE 0 END    [BonanzaCount]
		, CASE ivtTransactionTypeID WHEN 25 THEN ivdDelta ELSE 0 END    [IssuedCount]
		, CASE ivtTransactionTypeID WHEN 26 THEN ivdDelta ELSE 0 END    [PlayBackCount]
		, CASE ivtTransactionTypeID WHEN 27 THEN ivdDelta ELSE 0 END    [DamagedCount]
		, CASE ivtTransactionTypeID WHEN 32 THEN ivdDelta ELSE 0 END    [TransferCount]
from	InventoryItem 
		join InvTransaction on iiInventoryItemID = ivtInventoryItemID
		join InvTransactionDetail on ivtInvTransactionID = ivdInvTransactionID
		join InvLocations on ivdInvLocationID = ilInvLocationID
		left join IssueNames on ivtIssueNameID = inIssueNameID
		left join ProductItem item on item.ProductItemID = iiProductItemID
		left join ProductGroup pg on item.ProductGroupID = pg.ProductGroupID
where	item.OperatorID = @OperatorID
		and ivtGamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
		and ivtGamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
		and ivtGamingDate > '02/21/2019'
		and ( @Session = 0 
			  or ivtGamingSession = @Session
			 )
		and ( ilMachineID <> 0 
			  or ilStaffID <> 0
			 )
		and item.SalesSourceID = 1		-- Inventory source sale
)
insert into @Sales
(
	productName
	, Amount
	, gamingSession
	, gamingDate
)
select	fs.ItemName
		, SUM(Price * ( IssueCount + ReturnCount + DamageCount + SkipCount 
						+ TransferCount + BonanzaCount)) [Floor Sales]    -- ADD since these qtys are negative
		, fs.SessionNo
		, fs.gamingDate
from	FloorSales fs 
		join @AccrualProducts ap on fs.ItemName = ap.ItemName
group By fs.gamingDate,
		fs.SessionNo,
		fs.ItemName 

select	gamingDate,
		gamingSession,
		productName,
		sum(Amount) as Amount
from	@Sales
group by gamingDate,
		gamingSession,
		productName
	
end









GO

