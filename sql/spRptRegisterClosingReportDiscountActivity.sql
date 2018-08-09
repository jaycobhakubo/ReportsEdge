USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportDiscountActivity]    Script Date: 02/01/2013 09:36:02 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRegisterClosingReportDiscountActivity]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRegisterClosingReportDiscountActivity]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportDiscountActivity]    Script Date: 02/01/2013 09:36:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure  [dbo].[spRptRegisterClosingReportDiscountActivity] 
-- ============================================================================
-- 2012.6.18 jkn: TA11139 Adding support for returning discounts and discount
--  returns
-- 1/23/2013 (knc): US412/TA59 Function Discount is not showing in the Register Closing Report.
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
	discount			money
);

-- ============================================================================
-- Retrieve all of the discounts that were used or returned
-- ============================================================================
insert into @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	discount
)
select	--*
    isnull(rdi.ProductItemName, dt.DiscountTypeName /*'discount fix'*/)ProductItemName, 
	rr.StaffID, isnull(rdi.Price,DiscountAmount), rr.GamingDate, sp.GamingSession, s.LastName + ', ' + s.FirstName,                     -- DE7731
    rr.SoldFromMachineID,
   -- rd.Quantity ,rdi.Qty,isnull(rdi.Price,DiscountAmount)
    case when TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1))
         when TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1))
    end,
	case when rr.TransactionTypeId = 1 then sum(rd.Quantity * isnull(rdi.Qty,1) *  isnull(rdi.Price,DiscountAmount))
	     when rr.TransactionTypeId = 3 then sum(-1 * rd.Quantity * isnull(rdi.Qty,1) * isnull(rdi.Price,DiscountAmount))
	end
	----DiscountAmount 
from RegisterReceipt rr
	join RegisterDetail rd on (rr.RegisterReceiptID = rd.RegisterReceiptID)
	left join RegisterDetailItems rdi on (rdi.RegisterDetailID = rd.RegisterDetailID)
	left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
	left JOIN DiscountTypes dt ON ( rd.DiscountTypeID = dt.DiscountTypeID )
	join Staff s on rr.StaffID = s.StaffID
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
	and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
	and rr.SaleSuccess = 1
	and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3)
	

	
	and rr.OperatorID = @OperatorID
	and ((rdi.ProductTypeID = 14	and rdi.ProductItemName LIKE '%Discount%') or (dt.DiscountTypeID  is not null))
	and (@Session = 0 or sp.GamingSession = @Session)
    and (@StaffID = 0 or rr.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
	and rd.VoidedRegisterReceiptID IS NULL
    and (@MachineID = 0 or rr.SoldFromMachineID = @MachineID )    
group by rdi.ProductItemName, rr.StaffID, rdi.Price, rr.GamingDate
        ,sp.GamingSession, s.LastName, s.FirstName, rr.SoldFromMachineID
        ,rr.TransactionTypeId, DiscountAmount, dt.DiscountTypeName ;


insert into @SalesActivity
(
	productItemName,
	staffIdNbr, price, gamingDate, sessionNbr, staffName,       -- DE7731
    soldFromMachineId,
	itemQty,
	discount
)
 select CouponName, cpn.StaffID, CouponValue, GamingDate, GamingSession,  s.LastName + ', ' + s.FirstName , SoldFromMachineID, QuantityNet , NetSales
        from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session) cpn
        left join Staff s on cpn.StaffID = s.StaffID

 --PRODUCTION			
select 
    staffIdNbr,staffName, gamingDate
	, isnull(sessionNbr, -1)	 [sessionNbr]			-- 2011.07.22 bjs: allow for day-long, N/A sessions
	, productItemName
    , isnull(soldFromMachineId, 0) [soldFromMachineId]
    , price
    , sum(itemQty) as QTY      
    , sum(discount) as Value
from @SalesActivity
group by staffIdNbr,staffName,GamingDate,sessionNbr, productItemName, soldFromMachineId, price
order by staffIdNbr,gamingDate, sessionNbr ;






GO


