USE [Daily]
GO
/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportElectronicSalesActivity]    Script Date: 06/19/2012 08:02:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER procedure  [dbo].[spRptRegisterClosingReportElectronicSalesActivity] 
-- ============================================================================
-- 2012.6.18 jkn: TA11139 Adding support for returning electronic sales and returns
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
	electronic			money
);

--		
-- Insert Electronic Rows		
--
insert into @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
	soldFromMachineId,
	itemQty,
	electronic
)
select	
    rdi.ProductItemName,
	rr.StaffID, rdi.Price, rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
	rr.SoldFromMachineID,
	case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty)
	     when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty)
	end,
	case when rr.TransactionTypeId = 1 then sum(rd.Quantity * rdi.Qty * rdi.Price)
	     when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * rdi.Qty * rdi.Price)
	end
from RegisterReceipt rr
	join RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
	join RegisterDetailItems rdi ON (rdi.RegisterDetailID = rd.RegisterDetailID)
	left join SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
	join Staff s on rr.StaffID = s.StaffID
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
	and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
	and rr.SaleSuccess = 1
	and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3)
	and rr.OperatorID = @OperatorID
	and rdi.ProductTypeID in (1, 2, 3, 4, 5)
	and (@Session = 0 or sp.GamingSession = @Session)
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID is null	
	and (rdi.CardMediaID = 1 or rdi.CardMediaID is null) -- Electronic
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
group by rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate
        ,sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID
        ,rr.TransactionTypeId;         

-- PRODUCTION			
select 
    staffIdNbr,staffName, gamingDate
	, isnull(sessionNbr, -1)	 [sessionNbr]			-- 2011.07.22 bjs: allow for day-long, N/A sessions
	, productItemName
    , isnull(soldFromMachineId, 0) [soldFromMachineId]
    --, sum(price) as Price  ONLY SHOW SINGLE PRICE  0524
    , price
    , sum(itemQty) AS QTY      
    , sum(electronic) as Value
from @SalesActivity
group by staffIdNbr,staffName,GamingDate,sessionNbr, productItemName, soldFromMachineId, price
order by staffIdNbr,gamingDate, sessionNbr ;
