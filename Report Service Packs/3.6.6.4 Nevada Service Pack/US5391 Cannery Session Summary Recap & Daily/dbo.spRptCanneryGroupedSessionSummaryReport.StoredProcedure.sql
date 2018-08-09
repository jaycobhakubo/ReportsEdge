USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryReport]    Script Date: 08/15/2017 13:23:18 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCanneryGroupedSessionSummaryReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCanneryGroupedSessionSummaryReport]    Script Date: 08/15/2017 13:23:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Travis Pollock
-- Create date: 8/15/2017
-- Description:	Cannery Casino version of the spRptGroupedSessionSummaryReport
--              to include cannery bucks.
-- =============================================


CREATE PROCEDURE [dbo].[spRptCanneryGroupedSessionSummaryReport]
	@OperatorID as int,
	@StartDate as datetime,
	@EndDate as datetime,
	@Session as int
	 
AS

SET NOCOUNT ON;	

select	sp.GamingDate,
		sp.GamingSession,  
		ProgramName, 
		ManAttendance, 
		ElectronicSales,
		PaperSales, 
		ValidationSales,
		isnull(	sum(PaperSales) 
				+ sum(ElectronicSales) 
				+ sum(ValidationSales), 0
			   ) as TotalSales, 
		isnull(BucksAmount, 0) as BucksAmount,
		isnull(GiftCertAmount, 0) as GiftCertAmount,
		isnull(sum(BingoOtherSales) 
				+ (sum(Discounts) * -1)		-- Stored as a positive number
				- isnull(sum(BucksAmount), 0) 
				- isnull(sum(GiftCertAmount), 0) , 0
			   ) as Coupons,
		DeviceFees,
		isnull( sum(ActualCash) 
				+ sum(DebitCredit) 
				+ sum(Checks) 
				+ sum(MoneyOrders) 
				+ sum(GiftCards) 
				+ sum(Chips)
				+ sum(Coupons), 0
			   ) as ActualCash,
		isnull( sum(CashPrizes) 
				+ sum(CheckPrizes) 
				+ sum(MerchandisePrizes) 
				+ sum(OtherPrizes), 0
			   ) as PrizesPaid,
		CashPrizes,
		AccrualPayouts,
		AccrualIncrease,
		BeginningBank,
		EndingBank,
		BankFill,
		AccrualCashPayouts
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
group by sp.GamingDate, 
		sp.GamingSession, 
		ProgramName,
		ManAttendance, 
		PaperSales, 
		ElectronicSales, 
		BingoOtherSales,
		AccrualIncrease,
		BeginningBank,
		CashPrizes,
		AccrualPayouts,
		EndingBank,
		DeviceFees,
		AccrualCashPayouts, 
		ValidationSales, 
		BankFill, 
		BucksAmount,
		GiftCertAmount
order by GamingDate,GamingSession
  
Set nocount off	

























GO

