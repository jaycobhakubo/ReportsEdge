USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBoydGroupedSessionSummaryYTD]    Script Date: 01/07/2019 14:01:07 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBoydGroupedSessionSummaryYTD]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBoydGroupedSessionSummaryYTD]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBoydGroupedSessionSummaryYTD]    Script Date: 01/07/2019 14:01:07 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Travis Pollock
-- Create date: 7/27/2018
-- Description:	Boyd Session Summary Recap Year to Date
--				Boyd version of the spRptGroupedSessionSummaryReport
--              to include star points.
-- 20190107 tmp: Return Bingo Other sales. Removed Bingo Other sales from the
--               Coupons and Discounts calculation.
-- =============================================


CREATE PROCEDURE [dbo].[spRptBoydGroupedSessionSummaryYTD]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS

SET NOCOUNT ON;	

set @StartDate = cast ('01' + '/' + '01'  + '/' +
						   cast((datepart(year, @StartDate)) as nvarchar) as datetime);	

set @StartDate = dateadd(year, -1, @StartDate);		

-- Get the Bonus Validation amount to subtract the amount from Validations
declare @BonusBall table
(
	GamingDate			datetime
	, GamingSession		int
	, BonusAmount		money
)
insert into @BonusBall
(
	GamingDate
	, GamingSession
	, BonusAmount
)
select	rr.GamingDate
		, sp.GamingSession
		, case	when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
				when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
		end
from	RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
        and (@Session = 0 or sp.GamingSession = @Session)
        and rr.SaleSuccess = 1
        and rd.VoidedRegisterReceiptID is null
        and rr.TransactionTypeID in (1, 3)
        and rdi.ProductTypeID = 19
group by rr.GamingDate
	, sp.GamingSession
	, rr.TransactionTypeID; 				   					   

declare @YearToDate table
(
	GamingYear int,
	Attendance Int,
	ElectronicSales	money,
	PaperSales	money,
	ValidationSales money,
	TotalSales money,
	StarAmount money,
	BonusAmount money,
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
	WinCashBased Money,
	BingoOther money
)
insert into @YearToDate
(
	GamingYear,
	Attendance,
	ElectronicSales,
	PaperSales,
	BonusAmount,
	ValidationSales,
	TotalSales,
	StarAmount,
	Coupons,
	DeviceFees,
	ActualCash,
	PrizesPaid,
	AccrualPayouts,
	TotalPaid,
	AccrualIncreases,
	BingoOther
)
select	datepart(year, sp.GamingDate),
		isnull(sum(ManAttendance), 0), 
		isnull(sum(ElectronicSales), 0),
		isnull(sum(PaperSales), 0), 
		isnull(sum(BonusAmount), 0) as BonusBall,
		isnull(sum(ValidationSales), 0) 
			- isnull(sum(BonusAmount), 0)
				as ValidationSales,
		isnull( sum(PaperSales) 
				+ sum(ElectronicSales) 
				+ sum(ValidationSales)
				+ sum(BingoOtherSales), 0	-- 20190107 tmp Added Bingo Other
			   ) as TotalSales, 
		isnull(sum(StarAmount), 0) as StarAmount,
/*		isnull(sum(BingoOtherSales)			-- 20190107 tmp Removed Bingo Other
				 + */ 
				 isnull((sum(Discounts) * -1)	-- Stored as a positive number
				 + (sum(Coupons) * -1)		-- Stored as a positive number
				 - isnull(sum(StarAmount), 0) 
				 , 0
			   ) as Coupons,
		isnull(sum(DeviceFees), 0),
		isnull( (sum(BeginningBank)
				+ sum(BankFill)
				- sum(ActualCash)
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
		isnull(sum(AccrualIncrease), 0),
		isnull(sum(BingoOtherSales), 0)		-- 20190107 tmp Added Bingo Other
from	SessionSummary ss
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join ( select	GamingDate,
							GamingSession,
							StarAmount  
					from	dbo.FindStarPoints(@OperatorID, @StartDate, @EndDate, @Session)
				   ) fsp 
							on ( fsp.GamingDate = sp.GamingDate
								 and fsp.GamingSession = sp.GamingSession )
		left join @BonusBall bb on (	sp.GamingDate = bb.GamingDate
										and sp.GamingSession = bb.GamingSession)	
where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and sp.OperatorID = @OperatorID
        and (@Session = 0 
             or sp.GamingSession = @Session)
group by year(sp.GamingDate) 
order by year(sp.GamingDate);

update	@YearToDate
set		NetSales = TotalSales + StarAmount + Coupons;

update	@YearToDate
set		ExpectedCash = NetSales + DeviceFees;

update	@YearToDate
set		WinCashBased = NetSales - (PrizesPaid + AccrualPayouts);

update	@YearToDate
set		OverShort = ActualCash - ExpectedCash; 
		
select	*
from	@YearToDate
order by GamingYear;
  
Set nocount off;	











GO

