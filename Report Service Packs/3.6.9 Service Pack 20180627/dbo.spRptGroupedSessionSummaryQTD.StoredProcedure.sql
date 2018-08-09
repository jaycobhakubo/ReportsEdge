USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptGroupedSessionSummaryQTD]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptGroupedSessionSummaryQTD]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		FortuNet
-- Description:	<Session Summary Recap Quarter to Date >
-- US3731 - Add Quarter to Date to the Session Summary Recap.
-- 20150923(knc): Add coupon sales. 
-- 20160202 tmp: US4428/US4521 - Added the validaiton sales from the Session Summary table to the calcualtions. 
-- 20160202 tmp: Removed coupon sales, coupon sales are included in the Session Summary Discount column. 
-- 20160203 tmp: US4523 Added Bank Fills to expected cash. 
-- 20180403 tmp: US5550 Get device fees redeemed with points to add the amount back into the NV Taxable amount. 
--               When redeeming device fees with points the taxable amount was understated since the redeem amount was being 
--               deducted as a negative amount under Bingo Other and then again when as a Device Fee.
-- 20180628 tmp: Added flag to check if the account uses point redemptions. 
--=============================================
CREATE PROCEDURE [dbo].[spRptGroupedSessionSummaryQTD]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS

SET NOCOUNT ON;	

set @StartDate = cast ('01' + '/' + '01'  + '/' +
						   cast ((datepart(year, @StartDate)) as nvarchar) as datetime)
						   
declare @GetPointRedemptions int;

set @GetPointRedemptions = (
								select	SettingValue
								from	OperatorSettings
								where	GlobalSettingID = 295 -- Player interface id
										and OperatorID = @OperatorID
							)

Declare @Results table
(
	GamingYear Int,
	GamingQuarter Int,
	Attendance Int,
	CashReceived Money,
	NetSales Money,
	TotalPrizes Money,
	ProgressiveIncrease Money,
	WinAccrualBased Money,
	ProgressivePayouts Money,
	SessionCosts Money,
	ActualCash Money,
	ExpectedCash Money,
	OverShort Money,
	Deposit Money,
	PlayerSpend Money,
	ProgressiveCashPayouts Money,
	POSActualCash Money,
	DeviceFees Money
)
if @GetPointRedemptions = 2 -- Boyd BConnect
begin
	Insert into @Results
	(
		GamingYear,
		GamingQuarter,
		Attendance,
		CashReceived,
		NetSales,
		TotalPrizes,
		ProgressiveIncrease,
		WinAccrualBased,
		ProgressivePayouts,
		SessionCosts,
		ActualCash,
		ExpectedCash,
		OverShort,
		Deposit,
		ProgressiveCashPayouts,
		POSActualCash,
		DeviceFees
	)	

	select  DatePart(Year, sp.GamingDate), 
			DATEPART(Quarter, sp.GamingDate),
			Sum(ManAttendance), 
			Isnull((Sum(PaperSales) + Sum(ElectronicSales) + Sum(BingoOtherSales) + Sum(PullTabSales) + Sum(ConcessionSales)
				+ Sum(MerchandiseSales) - Sum(Discounts) /*- couponSales*/ + Sum(Tax) + Sum(DeviceFees) + SUM(ValidationSales)), 0),	-- US4521
			Isnull((Sum(PaperSales) + Sum(ElectronicSales) + Sum(BingoOtherSales) + Sum(PullTabSales)- Sum(Discounts) + SUM(ValidationSales) /*- couponSales*/ + sum(RedeemFees)), 0), -- US4521
			Isnull((Sum(CashPrizes) + Sum(CheckPrizes) + Sum(MerchandisePrizes) + Sum(PullTabPrizes) + Sum(OtherPrizes)), 0),
			Sum(AccrualIncrease),
			0,
			Sum(AccrualCashPayouts) AccrualCashPayouts,
			sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) + 
				sum(isnull(case when si.IsRegister = 0 then si.[value] else 0 end, 0)),
			Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(GiftCards) + Sum(Chips) + Sum(Coupons)), 0),
			ISNULL((Sum(BeginningBank) + SUM(BankFill) - SUM(AccrualPayouts) + Sum(MerchandisePrizes) + Sum(CheckPrizes) + Sum(PrizeFeesWithheld) + SUM(DeviceFees) 
				- sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) + Sum(Tax) + Sum(MerchandiseSales) + Sum(ConcessionSales)), 0),
			0,
			Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(Chips) + sum(GiftCards) + sum(Coupons) - Sum(EndingBank)), 0),
			SUM(AccrualCashPayouts),
			(isnull(sum(BeginningBank), 0) + isnull(sum(BankFill), 0) - Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(GiftCards) + Sum(Chips) + Sum(Coupons)), 0) - isnull(SUM(AccrualCashPayouts), 0) - isnull(sum(CashPrizes), 0)) * -1 ,
			isnull(sum(DeviceFees), 0) 
	from	(SessionSummary SS
			join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
			left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
			left join SessionCostItem SI on SC.SessionCostItemID = SI.Id)/*,*/
			/*Old school join No need for join*//*(select sum(NetSales) couponSales from dbo.FindCouponSales(@OperatorID,@StartDate,@EndDate,@Session)) as Coupon*/
			left join	(	select	GamingDate,
									GamingSession,
									sum(RedeemFees) as RedeemFees
							from	FindPointRedemptions (@OperatorID, @StartDate, @EndDate, isnull(@Session, 0)) 
							where	Voided = 0
							group by GamingDate, GamingSession
						)	fpr on fpr.GamingDate = sp.GamingDate and fpr.GamingSession = sp.GamingSession	
	where	sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
			and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
			and SP.OperatorID = @OperatorID
			and (@Session = 0 or sp.GamingSession = @Session)
	group by Year(sp.GamingDate), DatePart(QUARTER, sp.GamingDate)/*,couponSales*/
	order by Year(sp.GamingDate), DatePart(QUARTER, sp.GamingDate)
end
else
begin
	Insert into @Results
	(
		GamingYear,
		GamingQuarter,
		Attendance,
		CashReceived,
		NetSales,
		TotalPrizes,
		ProgressiveIncrease,
		WinAccrualBased,
		ProgressivePayouts,
		SessionCosts,
		ActualCash,
		ExpectedCash,
		OverShort,
		Deposit,
		ProgressiveCashPayouts,
		POSActualCash,
		DeviceFees
	)	

	select  DatePart(Year, sp.GamingDate), 
			DATEPART(Quarter, sp.GamingDate),
			Sum(ManAttendance), 
			Isnull((Sum(PaperSales) + Sum(ElectronicSales) + Sum(BingoOtherSales) + Sum(PullTabSales) + Sum(ConcessionSales)
				+ Sum(MerchandiseSales) - Sum(Discounts) /*- couponSales*/ + Sum(Tax) + Sum(DeviceFees) + SUM(ValidationSales)), 0),	-- US4521
			Isnull((Sum(PaperSales) + Sum(ElectronicSales) + Sum(BingoOtherSales) + Sum(PullTabSales)- Sum(Discounts) + SUM(ValidationSales) /*- couponSales*/ /*+ sum(RedeemFees)*/), 0), -- US4521
			Isnull((Sum(CashPrizes) + Sum(CheckPrizes) + Sum(MerchandisePrizes) + Sum(PullTabPrizes) + Sum(OtherPrizes)), 0),
			Sum(AccrualIncrease),
			0,
			Sum(AccrualCashPayouts) AccrualCashPayouts,
			sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) + 
				sum(isnull(case when si.IsRegister = 0 then si.[value] else 0 end, 0)),
			Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(GiftCards) + Sum(Chips) + Sum(Coupons)), 0),
			ISNULL((Sum(BeginningBank) + SUM(BankFill) - SUM(AccrualPayouts) + Sum(MerchandisePrizes) + Sum(CheckPrizes) + Sum(PrizeFeesWithheld) + SUM(DeviceFees) 
				- sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) + Sum(Tax) + Sum(MerchandiseSales) + Sum(ConcessionSales)), 0),
			0,
			Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(Chips) + sum(GiftCards) + sum(Coupons) - Sum(EndingBank)), 0),
			SUM(AccrualCashPayouts),
			(isnull(sum(BeginningBank), 0) + isnull(sum(BankFill), 0) - Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(GiftCards) + Sum(Chips) + Sum(Coupons)), 0) - isnull(SUM(AccrualCashPayouts), 0) - isnull(sum(CashPrizes), 0)) * -1 ,
			isnull(sum(DeviceFees), 0) 
	from	(SessionSummary SS
			join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
			left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
			left join SessionCostItem SI on SC.SessionCostItemID = SI.Id)/*,*/
			/*Old school join No need for join*//*(select sum(NetSales) couponSales from dbo.FindCouponSales(@OperatorID,@StartDate,@EndDate,@Session)) as Coupon*/
			--left join	(	select	GamingDate,
			--						GamingSession,
			--						sum(RedeemFees) as RedeemFees
			--				from	FindPointRedemptions (@OperatorID, @StartDate, @EndDate, isnull(@Session, 0)) 
			--				where	Voided = 0
			--				group by GamingDate, GamingSession
			--			)	fpr on fpr.GamingDate = sp.GamingDate and fpr.GamingSession = sp.GamingSession	
	where	sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
			and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
			and SP.OperatorID = @OperatorID
			and (@Session = 0 or sp.GamingSession = @Session)
	group by Year(sp.GamingDate), DatePart(QUARTER, sp.GamingDate)/*,couponSales*/
	order by Year(sp.GamingDate), DatePart(QUARTER, sp.GamingDate)
end

Update @Results
Set WinAccrualBased = NetSales - (TotalPrizes + ProgressiveIncrease),
	ExpectedCash = ExpectedCash + (NetSales - TotalPrizes)
	
Update @Results	
Set	OverShort = ActualCash - ExpectedCash,
	PlayerSpend = (NetSales / isnull(nullif(Attendance, 0), 1))

Select	GamingYear,
		GamingQuarter,
		Attendance,
		CashReceived,
		NetSales,
		TotalPrizes,
		ProgressiveIncrease,
		WinAccrualBased,
		ProgressivePayouts,
		SessionCosts,
		OverShort,
		Deposit,
		PlayerSpend,
		ProgressiveCashPayouts,
		POSActualCash,
		DeviceFees
From @Results
  
Set nocount off	








































GO

