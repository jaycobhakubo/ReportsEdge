USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPNPReport]    Script Date: 01/08/2013 14:12:46 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPNPReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPNPReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPNPReport]    Script Date: 01/08/2013 14:12:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptPNPReport]
	@StartDate		AS	SmallDateTime,
	@EndDate		AS	SmallDateTime,
	@GamingDate		AS int,
	@OperatorID as int = null
	
AS
-- ===========================================
-- Author: Fortunet
-- Date Created: I do not know
-- (1/8/2013) - knc: Add @OperatorID to fixed the problem in Crystal Report Subreport.
-- ==============================================	
SET NOCOUNT ON   
If @GamingDate = 0

SELECT  LBG.LBGameCompletedDate, LBG.CreateDate, LBG.ClosedSaleDate, LBG.GamingDate, LBG.ClientGameID,
	LBCS.*, LBCSD.*, LastName, FirstName
from History.dbo.LBGame LBG (Nolock)
join History.dbo.LBCardSale LBCS (nolock) on LBG.LBGameid = LBCS.LBGameID
Join History.dbo.LBCardSaleDetail LBCSD (nolock) on LBCS.LBCardSaleID = LBCSD.LBCardSaleID
join Player P (nolock) on LBCS.PlayerID = P.PlayerID
 WHERE  LBG.GamingDate >=CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
AND LBG.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
and isnull(LBCS.CancelCreditBalancesTransID,0) = 0
and LBG.GameCategoryID = 9

else
SELECT  LBG.LBGameCompletedDate, LBG.CreateDate, LBG.ClosedSaleDate, LBG.GamingDate, LBG.ClientGameID,
	LBCS.*, LBCSD.*, LastName, FirstName
from History.dbo.LBGame LBG (Nolock)
join History.dbo.LBCardSale LBCS (nolock) on LBG.LBGameid = LBCS.LBGameID
Join History.dbo.LBCardSaleDetail LBCSD (nolock) on LBCS.LBCardSaleID = LBCSD.LBCardSaleID
join Player P (nolock) on LBCS.PlayerID = P.PlayerID
 WHERE (LBCS.SaleDate >= @StartDate
AND LBCS.SaleDate <= @EndDate)
and isnull(LBCS.CancelCreditBalancesTransID,0) = 0
and LBG.GameCategoryID = 9

SET NOCOUNT OFF





GO


