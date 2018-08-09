USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptGroupedSessionSummaryReport]    Script Date: 10/07/2013 17:54:22 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptGroupedSessionSummaryReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptGroupedSessionSummaryReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptGroupedSessionSummaryReport]    Script Date: 10/07/2013 17:54:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- =============================================
CREATE PROCEDURE [dbo].[spRptGroupedSessionSummaryReport]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS
-- ==============
--	20150923(knc): Add coupon sales.
-- ================
SET NOCOUNT ON;	
select 

GamingDate, ProgramName, GamingSession, ManAttendance, PaperSales, ElectronicSales, 
BingoOtherSales,PullTabSales,ConcessionSales,MerchandiseSales,
Discounts, Coupon,CashPrizes,CheckPrizes,MerchandisePrizes,AccrualIncrease,
PullTabPrizes,BeginningBank,AccrualPayouts,PrizeFeesWithheld,Coupons,
Tax,ActualCash,DebitCredit,Checks,MoneyOrders,GiftCards,Chips,EndingBank,DeviceFees,
sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) as SessionCostsRegister,
sum(isnull(case when si.IsRegister = 0 then si.[value] else 0 end, 0)) as SessionCostsNonRegister
,OtherPrizes ,AccrualCashPayouts
from SessionSummary SS
     join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
     left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
     left join SessionCostItem SI on SC.SessionCostItemID = SI.Id
     left join (select GamingSession cpnGamingSession ,Netsales as Coupon from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session)) cpn on cpn.cpnGamingSession =  sp.GamingSession

where   
        GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and SP.OperatorID = @OperatorID
        and (@Session = 0 or sp.GamingSession = @Session)

group by 
     GamingDate, ProgramName, GamingSession, ManAttendance, PaperSales, ElectronicSales, 
BingoOtherSales,PullTabSales,ConcessionSales,MerchandiseSales,
Discounts,CashPrizes,CheckPrizes,MerchandisePrizes,AccrualIncrease,
PullTabPrizes,BeginningBank,AccrualPayouts,PrizeFeesWithheld,Coupons,
Tax,ActualCash,DebitCredit,Checks,MoneyOrders,GiftCards,Chips,EndingBank,DeviceFees
,OtherPrizes , AccrualCashPayouts, Coupon
order by GamingDate,GamingSession
  
Set nocount off	








GO

