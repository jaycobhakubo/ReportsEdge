USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportPaperSalesActivity]    Script Date: 10/17/2013 5:25:19 PM ******/
DROP PROCEDURE [dbo].[spRptRegisterClosingReportPaperSalesActivity]
GO

/****** Object:  StoredProcedure [dbo].[spRptRegisterClosingReportPaperSalesActivity]    Script Date: 10/17/2013 5:25:19 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure  [dbo].[spRptRegisterClosingReportPaperSalesActivity] 
-- ============================================================================
-- 2012.6.18 jkn: TA11139 Adding support for returning paper sales
-- 2013.10.17 tmp: Return inventory sales if @MachineID <> 0
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
	paper				money,          -- original field, represents paper sales made at a register
	paperSalesFloor 	money,          -- DE7731
	paperSalesTotal 	money           -- DE7731
);

-------------------------------------------------------------------------------------------
-- PAPER SALES
--
-- Paper sales: both register sales and inventory (floor sales)
-- 
insert @SalesActivity
(
	productItemName
    , staffIdNbr, staffName
    , soldFromMachineId
	, price, gamingDate, sessionNbr
	, itemQty
	, paper, paperSalesFloor, paperSalesTotal
)
select 
	ItemName
	, fps.StaffID, s.LastName + ', ' + s.FirstName
	, fps.soldFromMachineId
	, Price, GamingDate, SessionNo
	, Qty
	, RegisterPaper, FloorPaper, RegisterPaper + FloorPaper
from FindPaperSales(@OperatorID, @StartDate, @EndDate, @Session) fps
    join Staff s on fps.StaffID = s.StaffID
where 
    (@StaffID = 0 or s.StaffID = @StaffID or @CashMethod = 2)		-- Machine Mode must print activity for all staff
     and (@MachineID = 0 or fps.soldFromMachineId = @MachineID or fps.SoldFromMachineID IS NULL) -- Must return inventory sales
        

-- PRODUCTION			
select 
    staffIdNbr,staffName, gamingDate
	, isnull(sessionNbr, -1)	 [sessionNbr]			-- 2011.07.22 bjs: allow for day-long, N/A sessions
	, productItemName
    , isnull(soldFromMachineId, 0) [soldFromMachineId]
    , price
    , sum(itemQty) AS QTY      
    , (sum(paper) +
       sum(paperSalesFloor)) as Value
from @SalesActivity
group by staffIdNbr,staffName,GamingDate,sessionNbr, productItemName, soldFromMachineId, price
order by staffIdNbr,gamingDate, sessionNbr ;




GO

