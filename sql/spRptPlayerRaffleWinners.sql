USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerRaffleWinners]    Script Date: 04/08/2015 16:28:38 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerRaffleWinners]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerRaffleWinners]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerRaffleWinners]    Script Date: 04/08/2015 16:28:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------------------------------------------------------------
-- 12/05/11 BSB: DE9733 Added Address2
-- 2015.04.08 tmp: US3916 Added the players phone number.  
-- 2015.04.08 tmp: US3915 Added the Raffle Name. 
-- 2015.08.26 knc: Added new column on the result set setting "Raffle or Drawing". 
---------------------------------------------------------------------------------------------------------


CREATE PROCEDURE [dbo].[spRptPlayerRaffleWinners]
	@OperatorID     as int,				-- DE8906
	@StartDate		as SmallDateTime,
	@EndDate		as SmallDateTime
	,@spRaffleOrDrawingSetting int--Note: Do not rename this "@spRaffleOrDrawingSetting", it will affect the ReportCenter Raffle Winners Report.
								  --: This parameter is use in the PlayerRaffleWinners.rpt crystal report to configure the report title.
AS
	
SET NOCOUNT ON


--declare @RaffleOrDrawingSetting int
--set @RaffleOrDrawingSetting = cast((select SettingValue 
--									from OperatorSettings 
--									where GlobalSettingID = 182
--									and OperatorID = @OperatorId) as int)


/****Add Player Address in case of 2 players with same name****/
select	LastName, 
		FirstName, 
		P.PlayerId, 
		DTStamp, 
		Address1, 
		Address2, 
		City, 
		State, 
		Zip, 
		Phone,		-- US3916 
		prh.RaffleName, -- US3915
		prh.RaffleHistoryID -- US3915
		--,@RaffleOrDrawingSetting as SettingValue
from PlayerRaffleWinners prw
join Player P  on prw.PlayerID = P.PlayerID
left Join Address A  on P.AddressID = A.AddressID
left join PlayerRaffleHistory prh on prw.RaffleHistoryId = prh.RaffleHistoryId
-- JLW 7-20-2009 - Remove Winner from next raffle setting actualy removes the player from the table
--join PlayerRaffle PR (nolock) on PlayerRaffleWinners.PlayerID = PR.PlayerID /**Added the Entry Time from Player Raffle**/
where 
    CAST(CONVERT(varchar(12), DTStamp, 101) AS smalldatetime) >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
and CAST(CONVERT(varchar(12), DTStamp, 101) AS smalldatetime)  <=  CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
and (@OperatorID = 0 or prw.OperatorId = @OperatorID)	-- de8906
Group by prh.RaffleHistoryId, prh.RaffleName, p.PlayerID, LastName, FirstName, Address1, Address2, City, State, Zip, Phone, DTStamp
order by DTStamp, LastName, FirstName;

SET NOCOUNT OFF

















GO

