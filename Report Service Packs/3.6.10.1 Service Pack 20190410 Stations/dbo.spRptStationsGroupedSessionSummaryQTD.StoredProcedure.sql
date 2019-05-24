USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsGroupedSessionSummaryQTD]    Script Date: 04/10/2019 14:37:21 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptStationsGroupedSessionSummaryQTD]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptStationsGroupedSessionSummaryQTD]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsGroupedSessionSummaryQTD]    Script Date: 04/10/2019 14:37:21 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO









-- =============================================
-- Author:		Travis Pollock
-- Create date: 12/6/2016
-- Description:	Stations Session Summary Recap Quarter to Date
--				Stations Casino version of the spRptGroupedSessionSummaryReport
--              to include station bucks.
-- 20170302 tmp: DE13497 Actual Cash did not include the additional currency types. 
--               Could cause the over/short to be off when other currency types are used.
-- 20190410 tmp: Do not include backup progressive increases.
-- =============================================


CREATE PROCEDURE [dbo].[spRptStationsGroupedSessionSummaryQTD]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS

SET NOCOUNT ON;	

set @StartDate = cast ('01' + '/' + '01'  + '/' +
						   cast((datepart(year, @StartDate)) as nvarchar) as datetime);	

declare @YearToDate table
(
	GamingQuarter int,
	Attendance Int,
	ElectronicSales	money,
	PaperSales	money,
	ValidationSales money,
	TotalSales money,
	StationBucksAmount money,
	StationGiftCertAmount money,
	Coupons		money,
	NetSales	money,
	DeviceFees	money,
	ExpectedCash Money,
	ActualCash	money,
	OverShort Money,
	PrizesPaid	money,
	AccrualPayouts money,
	TotalPaid	money,
	AccrualIncreases money,
	WinCashBased Money
)
insert into @YearToDate
(
	GamingQuarter,
	Attendance,
	ElectronicSales,
	PaperSales,
	ValidationSales,
	TotalSales,
	StationBucksAmount,
	StationGiftCertAmount,
	Coupons,
	DeviceFees,
	ActualCash,
	PrizesPaid,
	AccrualPayouts,
	TotalPaid,
	AccrualIncreases
)
select	datepart(quarter, sp.GamingDate),
		isnull(sum(ManAttendance), 0), 
		isnull(sum(ElectronicSales), 0),
		isnull(sum(PaperSales), 0), 
		isnulL(sum(ValidationSales), 0),
		isnull( sum(PaperSales) 
				+ sum(ElectronicSales) 
				+ sum(ValidationSales), 0
			   ) as TotalSales, 
		isnull(sum(StationBucksAmount), 0) as StationBucksAmount,
		isnull(sum(StationGiftCertAmount), 0) as StationGiftCertAmount,
		isnull(sum(BingoOtherSales) 
				 + (sum(Discounts) * -1)	-- Stored as a positive number
				 - isnull(sum(StationBucksAmount), 0) 
				 - isnull(sum(StationGiftCertAmount), 0), 0
			   ) as Coupons,
		isnull(sum(DeviceFees), 0),
		isnull( (sum(BeginningBank)
				+ sum(BankFill)
				- sum(ActualCash)
				- sum(DebitCredit)
				- sum(Checks)
				- sum(MoneyOrders)
				- sum(GiftCards)
				- sum(Chips)
				- sum(Coupons)
				- sum(AccrualCashPayouts)
				- sum(CashPrizes)
				), 0) * -1 as ActualCash,
		isnull(sum(CashPrizes) 
				+ sum(CheckPrizes) 
				+ sum(MerchandisePrizes) 
				+ sum(OtherPrizes), 0
			   ) as PrizesPaid,
		isnull(sum(AccrualPayouts), 0),
		isnull(sum(CashPrizes) 
				+ sum(CheckPrizes) 
				+ sum(MerchandisePrizes) 
				+ sum(OtherPrizes)
				+ sum(AccrualPayouts), 0
			   ) as TotalPaid,
		isnull(sum(AccrualIncrease), 0)
			- isnull(sum(IncreaseAmount), 0) as AccrualIncrease
from	SessionSummary ss
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join ( select	GamingDate,
							GamingSession,
							StationBucksAmount  
					from	dbo.FindStationBucks(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fsb 
							on ( fsb.GamingDate = sp.GamingDate
								 and fsb.GamingSession = sp.GamingSession )
		left join ( select	GamingDate,
							GamingSession,
							StationGiftCertAmount  
					from	dbo.FindStationGiftCert(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fsgc 
							on ( fsgc.GamingDate = sp.GamingDate
								 and fsgc.GamingSession = sp.GamingSession )	
		left join ( select	GamingDate,
							GamingSession,
							IncreaseAmount  
					from	dbo.FindStationsAccrualBackups(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fsab 
							on ( fsab.GamingDate = sp.GamingDate
								 and fsab.GamingSession = sp.GamingSession )	
where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and sp.OperatorID = @OperatorID
        and (@Session = 0 
             or sp.GamingSession = @Session)
group by datepart(quarter, sp.GamingDate) 
order by datepart(quarter, sp.GamingDate);

update	@YearToDate
set		NetSales = TotalSales + StationBucksAmount + StationGiftCertAmount + Coupons;

update	@YearToDate
set		ExpectedCash = NetSales + DeviceFees;

update	@YearToDate
set		WinCashBased = NetSales - (PrizesPaid + AccrualPayouts);

update	@YearToDate
set		OverShort = ActualCash - ExpectedCash; 
		
select	*
from	@YearToDate
order by GamingQuarter;
  
Set nocount off;	












GO

