USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryRecapCashBased]    Script Date: 08/16/2017 08:47:54 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCanneryGroupedSessionSummaryRecapCashBased]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryRecapCashBased]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryRecapCashBased]    Script Date: 08/16/2017 08:47:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
CREATE PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryRecapCashBased]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS
-- ==============
--	2017.08.16 tmp: Version of the Session Summary Recap Cash Based
--					for Cannery to separate CAN Bucks from Coupons.
-- ================
SET NOCOUNT ON;	

select	sp.GamingDate 
		, ProgramName 
		, sp.GamingSession
		, ManAttendance
		, PaperSales
		, ElectronicSales
		, BingoOtherSales
		, PullTabSales
		, ConcessionSales
		, MerchandiseSales
		, Discounts
		, Coupon
		, CashPrizes
		, CheckPrizes
		, MerchandisePrizes
		, AccrualIncrease
		, PullTabPrizes
		, BeginningBank
		, AccrualPayouts
		, PrizeFeesWithheld
		, Coupons
		, Tax
		, ActualCash
		, DebitCredit
		, Checks
		, MoneyOrders
		, GiftCards
		, Chips
		, EndingBank
		, DeviceFees
		, sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) as SessionCostsRegister
		, sum(isnull(case when si.IsRegister = 0 then si.[value] else 0 end, 0)) as SessionCostsNonRegister
		, OtherPrizes 
		, AccrualCashPayouts
		, ValidationSales	
		, BankFill
		, BucksAmount
from	SessionSummary SS
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
		left join SessionCostItem SI on SC.SessionCostItemID = SI.Id
		left join (select GamingSession cpnGamingSession ,Netsales as Coupon from dbo.FindCouponSales(@OperatorID, @StartDate, @EndDate, @Session)) cpn on cpn.cpnGamingSession =  sp.GamingSession
		left join ( select	GamingDate,
							GamingSession,
							BucksAmount  
					from	dbo.FindBucks(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fb 
							on ( fb.GamingDate = sp.GamingDate
								 and fb.GamingSession = sp.GamingSession )	
where   
        sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and SP.OperatorID = @OperatorID
        and (@Session = 0 or sp.GamingSession = @Session)

group by sp.GamingDate, ProgramName, sp.GamingSession, ManAttendance, PaperSales, ElectronicSales, 
BingoOtherSales,PullTabSales,ConcessionSales,MerchandiseSales,
Discounts,CashPrizes,CheckPrizes,MerchandisePrizes,AccrualIncrease,
PullTabPrizes,BeginningBank,AccrualPayouts,PrizeFeesWithheld,Coupons,
Tax,ActualCash,DebitCredit,Checks,MoneyOrders,GiftCards,Chips,EndingBank,DeviceFees
,OtherPrizes , AccrualCashPayouts, Coupon, ValidationSales, BankFill, BucksAmount
order by GamingDate, GamingSession
  
Set nocount off;	



GO

