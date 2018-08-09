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
	ProgressiveCashPayouts Money
)
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
	ProgressiveCashPayouts
)	

select  DatePart(Year, GamingDate), 
		DATEPART(Quarter, GamingDate),
		Sum(ManAttendance), 
		Isnull((Sum(PaperSales) + Sum(ElectronicSales) + Sum(BingoOtherSales) + Sum(PullTabSales) + Sum(ConcessionSales)
			+ Sum(MerchandiseSales) - Sum(Discounts) - couponSales + Sum(Tax) + Sum(DeviceFees)), 0),
		Isnull((Sum(PaperSales) + Sum(ElectronicSales) + Sum(BingoOtherSales) + Sum(PullTabSales)- Sum(Discounts) - couponSales), 0),
		Isnull((Sum(CashPrizes) + Sum(CheckPrizes) + Sum(MerchandisePrizes) + Sum(PullTabPrizes) + Sum(OtherPrizes)), 0),
		Sum(AccrualIncrease),
		0,
		Sum(AccrualCashPayouts) AccrualCashPayouts,
		sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) + 
			sum(isnull(case when si.IsRegister = 0 then si.[value] else 0 end, 0)),
		Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(GiftCards) + Sum(Chips) + Sum(Coupons)), 0),
		ISNULL((Sum(BeginningBank) - SUM(AccrualPayouts) + Sum(MerchandisePrizes) + Sum(CheckPrizes) + Sum(PrizeFeesWithheld) + SUM(DeviceFees) 
			- sum(isnull(case when si.IsRegister = 1 then si.[value] else 0 end, 0)) + Sum(Tax) + Sum(MerchandiseSales) + Sum(ConcessionSales)), 0),
		0,
		Isnull((Sum(ActualCash) + Sum(DebitCredit) + Sum(Checks) + Sum(MoneyOrders) + Sum(Chips) - Sum(EndingBank)), 0),
		SUM(AccrualCashPayouts)
from	(SessionSummary SS
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join SessionSummarySessionCosts SC on SS.SessionSummaryID = SC.SessionSummaryID
		left join SessionCostItem SI on SC.SessionCostItemID = SI.Id),
		/*Old school join No need for join*/(select sum(NetSales) couponSales from dbo.FindCouponSales(@OperatorID,@StartDate,@EndDate,@Session)) as Coupon
where	GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and SP.OperatorID = @OperatorID
		and (@Session = 0 or GamingSession = @Session)
group by Year(sp.GamingDate), DatePart(QUARTER, sp.GamingDate),couponSales
order by Year(sp.GamingDate), DatePart(QUARTER, sp.GamingDate)

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
		ProgressiveCashPayouts
From @Results
  
Set nocount off	





















GO

