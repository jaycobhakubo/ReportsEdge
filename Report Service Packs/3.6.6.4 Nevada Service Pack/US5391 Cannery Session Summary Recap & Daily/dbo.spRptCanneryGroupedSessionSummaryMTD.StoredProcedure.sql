USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryMTD]    Script Date: 08/14/2017 16:43:49 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCanneryGroupedSessionSummaryMTD]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryMTD]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryMTD]    Script Date: 08/14/2017 16:43:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Travis Pollock
-- Create date: 8/14/2017
-- Description:	Cannery Session Summary Recap Month to Date
--				Cannery Casino version of the spRptGroupedSessionSummaryReport
--              to include station bucks.
-- =============================================


CREATE PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryMTD]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS

SET NOCOUNT ON;	

set @StartDate = cast ('01' + '/' + '01'  + '/' +
						   cast ((datepart(year, @StartDate)) as nvarchar) as datetime)

declare @MonthToDate table
(
	GamingMonth nvarchar(32),
	MonthNm	nvarchar(32),
	Attendance Int,
	ElectronicSales	money,
	PaperSales	money,
	ValidationSales money,
	TotalSales money,
	BucksAmount money,
	GiftCertAmount money,
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
insert into @MonthToDate
(
	GamingMonth,
	MonthNm,
	Attendance,
	ElectronicSales,
	PaperSales,
	ValidationSales,
	TotalSales,
	BucksAmount,
	GiftCertAmount,
	Coupons,
	DeviceFees,
	ActualCash,
	PrizesPaid,
	AccrualPayouts,
	TotalPaid,
	AccrualIncreases
)
select	datepart(month, sp.GamingDate),
		datename(month, sp.GamingDate),
		isnull(sum(ManAttendance), 0), 
		isnull(sum(ElectronicSales), 0),
		isnull(sum(PaperSales), 0), 
		isnulL(sum(ValidationSales), 0),
		isnull( sum(PaperSales) 
				+ sum(ElectronicSales) 
				+ sum(ValidationSales), 0
			   ) as TotalSales, 
		isnull(sum(BucksAmount), 0) as BucksAmount,
		isnull(sum(GiftCertAmount), 0) as GiftCertAmount,
		isnull(sum(BingoOtherSales) 
				 + (sum(Discounts) * -1)	-- Stored as a positive number
				 - isnull(sum(BucksAmount), 0) 
				 - isnull(sum(GiftCertAmount), 0), 0
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
from	SessionSummary ss
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join ( select	GamingDate,
							GamingSession,
							BucksAmount  
					from	dbo.FindBucks(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fb 
							on ( fb.GamingDate = sp.GamingDate
								 and fb.GamingSession = sp.GamingSession )
		left join ( select	GamingDate,
							GamingSession,
							GiftCertAmount  
					from	dbo.FindGiftCert(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fgc 
							on ( fgc.GamingDate = sp.GamingDate
								 and fgc.GamingSession = sp.GamingSession )		
where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and sp.OperatorID = @OperatorID
        and (@Session = 0 
             or sp.GamingSession = @Session)
group by month(sp.GamingDate), 
		datename(month, sp.GamingDate)
order by month(sp.GamingDate);

update	@MonthToDate
set		NetSales = TotalSales + BucksAmount + GiftCertAmount + Coupons;

update	@MonthToDate
set		ExpectedCash = NetSales + DeviceFees;

update	@MonthToDate
set		WinCashBased = NetSales - (PrizesPaid + AccrualPayouts);

update	@MonthToDate
set		OverShort = ActualCash - ExpectedCash; 
		
select	*
from	@MonthToDate
order by MonthNm;
  
Set nocount off;	



























GO

