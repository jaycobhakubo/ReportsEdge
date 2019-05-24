USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsGroupedSessionSummaryReport]    Script Date: 04/10/2019 14:37:39 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptStationsGroupedSessionSummaryReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptStationsGroupedSessionSummaryReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptStationsGroupedSessionSummaryReport]    Script Date: 04/10/2019 14:37:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Travis Pollock
-- Create date: 12/6/2016
-- Description:	Stations Casino version of the spRptGroupedSessionSummaryReport
--              to include station bucks.
-- 20190410 tmp: Do not include backup progressive increases.
-- =============================================


CREATE PROCEDURE [dbo].[spRptStationsGroupedSessionSummaryReport]
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
		isnull(StationBucksAmount, 0) as StationBucksAmount,
		isnull(StationGiftCertAmount, 0) as StationGiftCertAmount,
		isnull(sum(BingoOtherSales) 
				+ (sum(Discounts) * -1)		-- Stored as a positive number
				- isnull(sum(StationBucksAmount), 0) 
				- isnull(sum(StationGiftCertAmount), 0) , 0
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
		AccrualIncrease
			- isnull(sum(IncreaseAmount), 0) as AccrualIncrease,
		BeginningBank,
		EndingBank,
		BankFill,
		AccrualCashPayouts
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
		StationBucksAmount,
		StationGiftCertAmount
order by GamingDate,GamingSession
  
Set nocount off	




























GO

