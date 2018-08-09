USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptRaffleEntrantsByDate]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptRaffleEntrantsByDate]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptRaffleEntrantsByDate] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<US3920: Reports the players entered into each raffle over a date range>
--(knc)20150826:	Add additional settingvalue for raffle or drawing 
--					on the final result set.
-- 20170926 tmp: Added the players mag card number.	
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS SMALLDATETIME,
	@EndDate	AS SMALLDATETIME,
	@spRaffleOrDrawingSetting int--Note: Do not rename this "@spRaffleOrDrawingSetting", it will affect the ReportCenter Raffle Entry by Date Report.
								  --: This parameter is use in the RaffleEntrantsbyDate.rpt crystal report to configure the report title.

AS
	
SET NOCOUNT ON

--------------------- Testing ------------------------------
--Declare @OperatorID int,
--		@StartDate	SmallDateTime,
--		@EndDate	SmallDateTime
		
--Set @OperatorID = 1
--Set @StartDate = '04/08/2015'
--Set @EndDate = '04/08/2015'
-----------------------------------------------------------		

declare @RaffleOrDrawingSetting int
set @RaffleOrDrawingSetting = cast((select SettingValue 
									from OperatorSettings 
									where GlobalSettingID = 182
									and OperatorID = @OperatorId) as int)

Select	prh.RaffleHistoryId,
		prh.RaffleName,
		prhe.PlayerId,
		p.LastName,
		p.FirstName,
		p.Phone,
		p.EMail,
		a.Address1 + ' ' + a.Address2 as PlayerAddress,
		a.City,
		a.State,
		a.Zip,
		pmc.MagneticCardNo
		--,@RaffleOrDrawingSetting as SettingValue
From	PlayerRaffleHistory prh join PlayerRaffleHistoricEntry prhe on prh.RaffleHistoryId = prhe.RaffleHistoryId
		join Player p on prhe.PlayerId = p.PlayerID
		left join PlayerMagCards pmc on prhe.PlayerId = pmc.PlayerID
		left join Address a on p.AddressID = a.AddressID
Where	CAST(CONVERT(varchar(12), prh.RaffleStart, 101) AS smalldatetime) >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and CAST(CONVERT(varchar(12), prh.RaffleStart, 101) AS smalldatetime) <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
Order by prh.RaffleHistoryId, p.FirstName, p.LastName

SET NOCOUNT OFF












GO

