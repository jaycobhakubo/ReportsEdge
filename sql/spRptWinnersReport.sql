USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptWinnersReport]    Script Date: 03/01/2013 08:50:06 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptWinnersReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptWinnersReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptWinnersReport]    Script Date: 03/01/2013 08:50:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO









create proc [dbo].[spRptWinnersReport]

@OperatorID	Int,	
@StartDate	DateTime,
@EndDate	DateTime,
@PlayerID   Int

as
-- =====================
-- Author: Karlo Camacho
-- Date: 2/5/2013
-- ============================		
		
-- ===================================
-- TEST	
--declare
--@OperatorID	Int	,
--@StartDate	DateTime,
--@EndDate	DateTime,
--@PlayerID int

--set @OperatorID = 1
--Set @StartDate = '01/01/2000'
--Set @EndDate = '12/31/2012'
--set @PlayerID = 0
--END TEST
-- ===================================

Select	pt.GamingDate,
		pt.PayoutTransNumber,
		p.FirstName,
		p.MiddleInitial,
		p.LastName,
		Sum(isnull(ptdc.Amount, 0) + isnull(ptdch.CheckAmount, 0) + isnull(ptdm.PayoutValue, 0) + isnull(ptdo.PayoutValue, 0)) as Win
,coalesce(sp.GamingSession
,sp2.GamingSession
,sp3.GamingSession
,sp4.GamingSession
,sp5.Gamingsession
,sp6.GamingSession,null)[Session]

From PayoutTrans pt
Join Player p on pt.PlayerID = p.PlayerID
Join PayoutTransDetailCash ptdc on pt.PayoutTransID = ptdc.PayoutTransID
Left Join PayoutTransDetailCheck ptdch on pt.PayoutTransID = ptdch.PayoutTransID
Left Join PayoutTransDetailMerchandise ptdm on pt.PayoutTransID = ptdm.PayoutTransID
Left Join PayoutTransDetailOther ptdo on pt.PayoutTransID = ptdo.PayoutTransID
left join  PayoutTransBingoGame ptbg on ptbg.PayoutTransID = pt.PayoutTransID
left join sessionGamesPlayed sgp on sgp.SessionGamesPlayedID = ptbg.SessionGamesPlayedID
left join sessionPlayed sp on sp.SessionPlayedID = sgp.sessionPlayedID
left join sessionPlayed sp2 on sp2.sessionPlayedID = ptbg.SessionPlayedID
left join PayoutTransBingoGoodNeighbor ptgn on ptgn.PayoutTransID = pt.PayoutTransID
left join sessiongamesplayed sgp2 on sgp2.SessionGamesPlayedID = ptgn.SessionGamesPlayedID
left join sessionPlayed sp3 on sp3.sessionPlayedID = sgp2.SessionPlayedID
left join PayoutTransBingoCustom ptbc on ptbc.PayoutTransID = pt.PayoutTransID
left join SessionPlayed sp4 on sp4.sessionplayedID = ptbc.sessionplayedid
left join sessiongamesplayed  sgp3 on sgp3.sessiongamesplayedID = ptbc.sessiongamesplayedID
left join sessionplayed sp5 on sp5.sessionplayedID = sgp3.sessionplayedID
left join payoutTransBingoRoyalty ptbr on ptbr.PayoutTransID = pt.PayoutTransID
left join sessiongamesplayed  sgp4 on sgp4.sessiongamesplayedID = ptbr.sessiongamesplayedID
left join sessionplayed sp6 on sp6.sessionplayedID = sgp4.sessionplayedID
Where pt.OperatorID = @OperatorID
And pt.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
And pt.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)

And (p.PlayerID = @PlayerID /*or @PlayerID = 0*/)
And pt.VoidTransID Is null
Group By pt.GamingDate, pt.PayoutTransNumber, p.LastName, p.FirstName, p.MiddleInitial,sp.GamingSession
,sp2.GamingSession,sp3.GamingSession,sp4.GamingSession ,sp5.Gamingsession,sp6.GamingSession

--109
--23





GO


