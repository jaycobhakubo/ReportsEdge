USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptGroupedSessionSummaryReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptGroupedSessionSummaryReport]
GO

USE [Daily]
GO

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
-- 20160202 tmp: US4428/US4521 - Added the validaiton sales from the Session Summary table to the calcualtions. 
-- 20160203 tmp: US4523 Added bank fills. 
-- 20180403 tmp: US5550 Get device fees redeemed with points to add the amount back into the NV Taxable amount. 
--               When redeeming device fees with points the taxable amount was understated since the redeem amount was being 
--               deducted as a negative amount under Bingo Other and then again when as a Device Fee.
-- 2018.06.27 tmp: Added flag to enable finding the point redemptions. 
-- ================
SET NOCOUNT ON;

declare @GetPointRedemptions int;

set @GetPointRedemptions = (
								select	SettingValue
								from	OperatorSettings
								where	GlobalSettingID = 295 -- Player interface id
										and OperatorID = @OperatorID
							)
if @GetPointRedemptions = 2 --Boyd BConnect
begin	
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
			, ValidationSales	-- US4521
			, BankFill
			, RedeemFees
	from	SessionSummary SS
			join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
			left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
			left join SessionCostItem SI on SC.SessionCostItemID = SI.Id
			left join (	select	GamingSession cpnGamingSession 
								, Netsales as Coupon 
						from	dbo.FindCouponSales (@OperatorID, @StartDate, @EndDate, @Session)
					  ) cpn on cpn.cpnGamingSession =  sp.GamingSession
			left join ( select  GamingDate,
								GamingSession,
								isnull(sum(RedeemFees), 0) as RedeemFees
						from	dbo.FindPointRedemptions (@OperatorID, @StartDate, @EndDate, @Session)
						where	Voided = 0
						group by GamingDate, GamingSession
					  ) fpr on fpr.GamingDate = sp.GamingDate and fpr.GamingSession = sp.GamingSession
	where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
			and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
			and SP.OperatorID = @OperatorID
			and (@Session = 0 or sp.GamingSession = @Session)
	group by sp.GamingDate, ProgramName, sp.GamingSession, ManAttendance, PaperSales, ElectronicSales, 
			BingoOtherSales,PullTabSales,ConcessionSales,MerchandiseSales,
			Discounts,CashPrizes,CheckPrizes,MerchandisePrizes,AccrualIncrease,
			PullTabPrizes,BeginningBank,AccrualPayouts,PrizeFeesWithheld,Coupons,
			Tax,ActualCash,DebitCredit,Checks,MoneyOrders,GiftCards,Chips,EndingBank,DeviceFees
			,OtherPrizes , AccrualCashPayouts, Coupon, ValidationSales	/*US4521*/, BankFill, RedeemFees
	order by sp.GamingDate,sp.GamingSession
end
else
begin
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
			, 0 as Coupon
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
			, ValidationSales	-- US4521
			, BankFill
			, 0 as RedeemFees
	from	SessionSummary SS
			join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
			left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
			left join SessionCostItem SI on SC.SessionCostItemID = SI.Id
			--left join (	select	GamingSession cpnGamingSession 
			--					, Netsales as Coupon 
			--			from	dbo.FindCouponSales (@OperatorID, @StartDate, @EndDate, @Session)
			--		  ) cpn on cpn.cpnGamingSession =  sp.GamingSession
			--left join ( select  GamingDate,
			--					GamingSession,
			--					isnull(sum(RedeemFees), 0) as RedeemFees
			--			from	dbo.FindPointRedemptions (@OperatorID, @StartDate, @EndDate, @Session)
			--			where	Voided = 0
			--			group by GamingDate, GamingSession
			--		  ) fpr on fpr.GamingDate = sp.GamingDate and fpr.GamingSession = sp.GamingSession
	where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
			and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
			and SP.OperatorID = @OperatorID
			and (@Session = 0 or sp.GamingSession = @Session)
	group by sp.GamingDate, ProgramName, sp.GamingSession, ManAttendance, PaperSales, ElectronicSales, 
			BingoOtherSales,PullTabSales,ConcessionSales,MerchandiseSales,
			Discounts,CashPrizes,CheckPrizes,MerchandisePrizes,AccrualIncrease,
			PullTabPrizes,BeginningBank,AccrualPayouts,PrizeFeesWithheld,Coupons,
			Tax,ActualCash,DebitCredit,Checks,MoneyOrders,GiftCards,Chips,EndingBank,DeviceFees
			,OtherPrizes , AccrualCashPayouts, /*Coupon,*/ ValidationSales	/*US4521*/, BankFill/*, RedeemFees*/
	order by sp.GamingDate,sp.GamingSession
end
  
Set nocount off	


GO

