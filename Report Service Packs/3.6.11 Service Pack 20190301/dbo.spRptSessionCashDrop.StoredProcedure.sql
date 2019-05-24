USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionCashDrop]    Script Date: 03/01/2019 12:43:23 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionCashDrop]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionCashDrop]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionCashDrop]    Script Date: 03/01/2019 12:43:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		FortuNet
-- Create date: 10/01/2018
-- Description:	US5695 Session Cash Drop Slip. Return the bank dropped in the Session Summary.
-- 20190301 tmp: Order using the order set in Currency Detail.
-- =============================================
CREATE procedure [dbo].[spRptSessionCashDrop]
	@OperatorID		int
	, @StartDate	datetime
	, @Session		int
as
begin

set nocount on;

select	sp.GamingDate
		, sp.GamingSession
		, cd.cdDenomName
		, sac.Quantity
		, cd.cdValue
		, sac.CurrencyValue
		, cd.cdOrder
from	SessionSummaryActualCashDenoms sac with (nolock)
		join SessionSummary ss with (nolock) on sac.SessionSummaryID = ss.SessionSummaryID
		join SessionPlayed sp with (nolock) on ss.SessionPlayedID = sp.SessionPlayedID
		join CurrencyDetail cd with (nolock) on sac.cdCurrencyDetailID = cd.cdCurrencyDetailID
where	sp.OperatorID = @OperatorID
		and sp.GamingDate = CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and (	@Session = 0 
				or sp.GamingSession = @Session
			)
order by cd.cdOrder

set nocount off;

end




GO

