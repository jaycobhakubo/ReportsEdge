USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryDaily]    Script Date: 08/14/2017 16:43:35 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCanneryGroupedSessionSummaryDaily]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryDaily]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryDaily]    Script Date: 08/14/2017 16:43:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Travis Pollock
-- Create date: 08/14/2017
-- Description:	Cannery Casino version of the spRptGroupedSessionSummaryReport
--              to include cannery bucks. Returns the daily totals.
-- =============================================


CREATE PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryDaily]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime	 
AS

SET NOCOUNT ON;	

declare @Session int = 0;

select	sp.GamingDate,
		isnull(sum(ManAttendance), 0) as ManAttendance, 
		isnull(sum(ElectronicSales), 0) as ElectronicSales,
		isnull(sum(PaperSales), 0) as PaperSales, 
		isnull(sum(ValidationSales), 0) as ValidationSales,
		isnull(	sum(PaperSales) 
				+ sum(ElectronicSales) 
				+ sum(ValidationSales), 0
			   ) as TotalSales, 
		isnull(sum(BucksAmount), 0) as BucksAmount,
		isnull(sum(GiftCertAmount), 0) as GiftCertAmount,
		isnull(sum(BingoOtherSales) 
				+ (sum(Discounts) * -1) -- Stored as a positive number	
				- isnull(sum(BucksAmount), 0) 
				- isnull(sum(GiftCertAmount), 0) , 0
			   ) as Coupons,
		isnull(sum(DeviceFees), 0) as DeviceFees,
		isnull( sum(ActualCash) 
				+ sum(DebitCredit) 
				+ sum(Checks) 
				+ sum(MoneyOrders) 
				+ sum(GiftCards) 
				+ sum(Chips), 0
				+ sum(Coupons), 0
			   ) as ActualCash,
		isnull( sum(CashPrizes) 
				+ sum(CheckPrizes) 
				+ sum(MerchandisePrizes) 
				+ sum(OtherPrizes), 0
			   ) as PrizesPaid,
		isnull(sum(CashPrizes), 0) as CashPrizes,
		isnull(sum(AccrualPayouts), 0) as AccrualPayouts ,
		isnull(sum(AccrualIncrease), 0) as AccrualIncrease,
		isnull(sum(BeginningBank), 0) as BeginningBank,
		isnull(sum(EndingBank), 0) as EndingBank,
		isnull(sum(BankFill), 0) as BankFill,
		isnull(sum(AccrualCashPayouts), 0) as AccrualCashPayouts
from	SessionSummary ss
		join SessionPlayed SP on SS.SessionPlayedID = SP.SessionPlayedID
		left join (	select	GamingDate,
							GamingSession,
							sum(BucksAmount) as BucksAmount  
					from	dbo.FindBucks(@OperatorID, @StartDate, @EndDate, @Session)
					group by GamingDate, 
							GamingSession
				   ) fb 
							on ( fb.GamingDate = sp.GamingDate
							     and fb.GamingSession = sp.GamingSession
							    )
		left join (	select	GamingDate,
							GamingSession,
							sum(GiftCertAmount) as GiftCertAmount  
					from	dbo.FindGiftCert(@OperatorID, @StartDate, @EndDate, @Session)
					group by GamingDate,
							GamingSession
				   ) fgc 
							on ( fgc.GamingDate = sp.GamingDate	
								 and fgc.GamingSession = sp.GamingSession
								)
where   sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
		and sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and sp.OperatorID = @OperatorID
group by sp.GamingDate
order by GamingDate;
  
Set nocount off;	




GO

