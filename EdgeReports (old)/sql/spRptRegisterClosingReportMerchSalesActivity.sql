USE [Daily]
GO
/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportMerchSalesActivity]    Script Date: 06/19/2012 08:23:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure  [dbo].[spRptRegisterClosingReportMerchSalesActivity] 
-- ============================================================================
-- 2012.6.18 jkn: TA11139 Adding support for returning Merchandise and 
--  consession sales
-- ============================================================================
@OperatorID		as int,
@StartDate		as datetime,
@EndDate		as datetime,
@StaffID		as int,
@Session		as int,
@MachineID      as int
as
	
-- Verfify POS sending valid values
set @StaffID = isnull(@StaffID, 0);
set @Session = isnull(@Session, 0);
set @MachineID = isnull(@MachineID, 0);

-- FIX EDGE 3.4 PATCH
-- When in Machine Mode (2) display all staff members when printing
declare @CashMethod int;
select @CashMethod = CashMethodID from Operator
where OperatorID = @OperatorID;
-- END EDGE 3.4 PATCH

-- Results table	
declare @SalesActivity table
(
	productItemName		nvarchar(64),
	staffIdNbr          int,            -- DE7731
	staffName           nvarchar(64),
	soldFromMachineId   int,
	itemQty			    int,            -- TC822
	issueQty			int,
	returnQty			int,
	skipQty				int,
	damageQty			int,		
	pricePaid           money,
	price               money,          -- DE7731
	gamingDate          datetime,       -- DE7731
	sessionNbr          int,            -- DE7731
	merchandise			money
);

-- ============================================================================
-- Adding support for returning Merchandise and Concessions sales and adjusts
--  for any returned products
-- ============================================================================
insert into @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,    -- DE7731
	soldFromMachineId,
	itemQty,
	merchandise
)
select	
        rdi.ProductItemName, 
		rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,   -- DE7731
        rr.SoldFromMachineID,
		case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty)
		     when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty)
		end,
		case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)
		     when rr.TransactionTypeId = 3 then sum (-1 * rd.Quantity * rdi.Qty * rdi.Price)
		end
from RegisterReceipt rr
	join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
	and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)
	and rr.SaleSuccess = 1
	and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns
	and rr.OperatorID = @OperatorID
	and (rdi.ProductTypeID = 7 or rdi.ProductTypeId = 6) --Merchandise or Concessions
	and (@Session = 0 or sp.GamingSession = @Session)
	and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)	-- DE8882
	and rd.VoidedRegisterReceiptID IS NULL
	and (rdi.CardMediaID = 1 OR rdi.CardMediaID IS NULL) -- Electronic
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
GROUP BY  rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate
        , sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID
        , rr.TransactionTypeId;

-- PRODUCTION			
select 
    staffIdNbr,staffName, gamingDate
	, isnull(sessionNbr, -1)	 [sessionNbr]			-- 2011.07.22 bjs: allow for day-long, N/A sessions
	, productItemName
    , isnull(soldFromMachineId, 0) [soldFromMachineId]
    , price
    , sum(itemQty) AS QTY      
    , sum(merchandise) as Value
from @SalesActivity
group by staffIdNbr,staffName,GamingDate,sessionNbr, productItemName, soldFromMachineId, price
order by staffIdNbr,gamingDate, sessionNbr ;

