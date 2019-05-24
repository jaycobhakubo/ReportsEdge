USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPayoutsByLevel]    Script Date: 12/19/2018 15:09:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPayoutsByLevel]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPayoutsByLevel]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPayoutsByLevel]    Script Date: 12/19/2018 15:09:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[spRptPayoutsByLevel]
-- ============================================================================
-- Author:		FortuNet
-- Description:	Returns the total payout amount and number of payouts grouped by level.
-- 20181219 tmp: US5746
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate	as smalldatetime,
	@Session	as int
as
begin
	
-- SET NOCOUNT ON added to prevent extra result sets from
set nocount on;

declare @Results table
(
	CardLevelID	int
	, CardLevelName nvarchar(64)
	, PayoutAmount	money
	, NbrPayouts	int
)
insert into @Results
(
	CardLevelID
	, CardLevelName
	, PayoutAmount
	, NbrPayouts
)
select	pbg.CardLevelId
		, pbg.CardLevelName
		, sum(isnull(pdc.Amount, 0)
			+ isnull(pdck.CheckAmount, 0)
			+ isnull(pdcr.NonRefundable, 0) 
			+ isnull(pdcr.Refundable, 0) 
			+ isnull(pdm.PayoutValue, 0)
			+ isnull(pdm.PayoutValue, 0)) as PayoutAmount
		, count(CardLevelId) as NbrPayouts
from	PayoutTrans pt
		join PayoutTransBingoGame pbg on pt.PayoutTransID = pbg.PayoutTransID
		left join PayoutTransDetailCash pdc on pbg.PayoutTransID = pdc.PayoutTransID
		left join PayoutTransDetailCheck pdck on pbg.PayoutTransID = pdck.PayoutTransID
		left join PayoutTransDetailCredit pdcr on pbg.PayoutTransID = pdcr.PayoutTransID
		left join PayoutTransDetailMerchandise pdm on pbg.PayoutTransID = pdm.PayoutValue
		left join PayoutTransDetailOther ptdo on pbg.PayoutTransID = pdm.PayoutTransID
		left join SessionGamesPlayed sgp on pbg.SessionGamesPlayedID = sgp.SessionGamesPlayedID
		left join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
where	pt.OperatorID = @OperatorID
		and pt.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		and pt.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		and (	
				@Session = 0 
				or sp.GamingSession = @Session
			)
		and pt.VoidTransID is null
		and pt.TransTypeID = 36 -- Payout
group by pbg.CardLevelId
	, pbg.CardLevelName

select	*
from	@Results
order by CardLevelID;

set nocount off;

end;


GO

