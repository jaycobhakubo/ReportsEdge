USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpend]    Script Date: 03/06/2013 14:11:34 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerSpend]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerSpend]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpend]    Script Date: 03/06/2013 14:11:34 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptPlayerSpend]
-- ============================================================================
-- Author:		FortuNet
-- Description:	Returns the player spend information
--
-- ????.??.?? - Initial implementation
-- 2011.09.06 bjs: Added div by zero logic
-- 2013.09.10 jkn: Added a function to retrive the total spend amount.
--  The discount amount is set to 0 since this is being handled in the
--  spend function.
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate as smallDatetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
declare @spendTable table (
    xPlayerId int
    ,xTotalSpend money
    ,xAvgSpend money)
    
insert into @spendTable select * from fnGetSpendAveragePerPlayer(@operatorId, @startDate, @endDate, default)

;with RESULTS
(FirstName, LastName, PlayerID, OperatorID, MagneticCardNo, Spend, Discount, SessionsPlayed, DaysPlayed, LastVisitDate)
as
(
    SELECT FirstName, LastName, RR.PlayerID, PIN.OperatorID, PMC.MagneticCardNo,
--        isnull(Sum(Quantity * PackagePrice), 0)  AS Spend,
--        isnull(Sum(Quantity * DiscountAmount), 0) as Discount,
        spend.xTotalSpend as spend, -- 2013.09.10
        0 as Discount,  -- 2013.09.10
        isnull(Count(Distinct(SessionPlayedID)), 0) as SessionsPlayed,
        isnull(Count(Distinct(RR.GamingDate)), 0) as DaysPlayed,
        LastVisitDate
    FROM   PlayerInformation PIN (nolock) 
        JOIN  RegisterReceipt RR (nolock) on PIN.PlayerID = RR.PlayeriD
        JOIN Player P (nolock) ON PIN.PlayerID = P.PlayerID
        Left Join PlayerMagCards PMC (nolock) on PMC.PlayerID = P.PlayerID
        JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID
        join @spendTable spend on p.PlayerId = spend.xPlayerId
    Where PIN.OperatorID = @OperatorID
        and RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
        and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)  
        and RD.VoidedRegisterReceiptID is null
        and RR.SaleSuccess = 1
    group by  FirstName, LastName, RR.PlayerID, LastVisitDate, PIN.OperatorID, PMC.MagneticCardNo, spend.xTotalSpend
)

select FirstName, LastName, PlayerID, OperatorID, MagneticCardNo, Spend, Discount, SessionsPlayed, DaysPlayed
    , case when DaysPlayed = 0 then 0 --2011.09.06
        else (Spend / DaysPlayed)
        end  [DailyAVG]
    , case when SessionsPlayed = 0 then 0 --2011.09.06
        else (Spend / SessionsPlayed)
        end [SessionAVG]
    , LastVisitDate
from RESULTS;

END;




GO


