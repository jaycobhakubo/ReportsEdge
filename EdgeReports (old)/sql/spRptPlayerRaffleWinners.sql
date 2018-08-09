GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerRaffleWinners]    Script Date: 12/05/2011 13:49:08 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
--12/05/11 BSB: DE9733 Added Address2


CREATE PROCEDURE [dbo].[spRptPlayerRaffleWinners]
	@OperatorID     as int,				-- DE8906
	@StartDate		as SmallDateTime,
	@EndDate		as SmallDateTime
AS
	
SET NOCOUNT ON
/****Add Player Address in case of 2 players with same name****/
select LastName, FirstName, P.PlayerId, DTStamp, Address1, Address2, City, State, Zip
from PlayerRaffleWinners 
join Player P  on PlayerRaffleWinners.PlayerID = P.PlayerID
left Join Address A  on P.AddressID = A.AddressID
-- JLW 7-20-2009 - Remove Winner from next raffle setting actualy removes the player from the table
--join PlayerRaffle PR (nolock) on PlayerRaffleWinners.PlayerID = PR.PlayerID /**Added the Entry Time from Player Raffle**/
where 
    CAST(CONVERT(varchar(12), DTStamp, 101) AS smalldatetime) >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
and CAST(CONVERT(varchar(12), DTStamp, 101) AS smalldatetime)  <=  CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
and (@OperatorID = 0 or OperatorId = @OperatorID)	-- de8906
order by DTStamp, LastName, FirstName;

SET NOCOUNT OFF


Go


