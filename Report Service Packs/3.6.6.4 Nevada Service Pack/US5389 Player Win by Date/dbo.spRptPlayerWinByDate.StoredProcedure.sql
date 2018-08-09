USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerWinByDate]    Script Date: 08/09/2017 17:03:53 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerWinByDate]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerWinByDate]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerWinByDate]    Script Date: 08/09/2017 17:03:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



create procedure [dbo].[spRptPlayerWinByDate]
-- ============================================================================
-- Author:		FortuNet
-- Description:	Returns the player spend information
--
-- 20170809 tmp: Return the payouts for each player.
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate as smallDatetime
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;
	
declare @Results table
(
	MagneticCardNo	nvarchar(32),
	LastName		nvarchar(32),
	FirstName		nvarchar(32),
	Regular			money,
	Jackpot			money,
	dtstamp			datetime
)
insert into @Results
(
	MagneticCardNo,
	LastName,
	FirstName,
	Regular,
	Jackpot,
	dtstamp
)	
Select	pmc.MagneticCardNo,
		p.LastName,
		p.FirstName,
		case when pt.AccrualTransID is null then Sum(isnull(ptdc.Amount, 0) + isnull(ptdch.CheckAmount, 0) + isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0))
			 else 0
		end as Regular,
		case when pt.AccrualTransID is not null then Sum(isnull(ptdc.Amount, 0) + isnull(ptdch.CheckAmount, 0) + isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0))
			 else 0
		end as Jackpot,
		pt.DTStamp
From	PayoutTrans pt
		--left Join Player p on pt.PlayerID = p.PlayerID
		--left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
		Join PayoutTransDetailCash ptdc on pt.PayoutTransID = ptdc.PayoutTransID
		Left Join PayoutTransDetailCheck ptdch on pt.PayoutTransID = ptdch.PayoutTransID
		Left Join PayoutTransDetailMerchandise ptdm on pt.PayoutTransID = ptdm.PayoutTransID
		Left Join PayoutTransDetailOther ptdo on pt.PayoutTransID = ptdo.PayoutTransID
		left join PayoutTransBingoGame ptbg on ptbg.PayoutTransID = pt.PayoutTransID
		left join PayoutTransBingoGoodNeighbor ptgn on ptgn.PayoutTransID = pt.PayoutTransID
		left join PayoutTransBingoCustom ptbc on ptbc.PayoutTransID = pt.PayoutTransID
		left join payoutTransBingoRoyalty ptbr on ptbr.PayoutTransID = pt.PayoutTransID
		left join ProgramGameWinners pgw on pgw.pgwSessionGamesPlayedID = ptbg.SessionGamesPlayedID and pgw.pgwMasterCardNo = ptbg.MasterCardNumber
		left join BingoCardHeader bch on pgw.pgwMasterCardNo = bch.bchMasterCardNo and pgw.pgwSessionGamesPlayedID = bch.bchSessionGamesPlayedID
		left join RegisterDetailItems rdi on bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID
		left join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
		left join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
		left join Player p on rr.PlayerID = p.PlayerID
		left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
Where	pt.OperatorID = @OperatorID
		And pt.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		And pt.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		And pt.VoidTransID Is null
Group By pt.PayoutTransNumber, p.LastName, p.FirstName, p.MiddleInitial, pmc.MagneticCardNo, pt.AccrualTransID, pt.DTStamp
order by p.LastName, p.FirstName, pt.DTStamp;

select	*
from	@Results
order by LastName, FirstName, dtstamp;

end;


GO

