USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptMenuCardCount]    Script Date: 09/05/2013 16:19:20 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptMenuCardCount]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptMenuCardCount]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptMenuCardCount]    Script Date: 09/05/2013 16:19:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptMenuCardCount]
(
@OperatorID as Int,
@POSMenuID as Int,
@ProgramID as Int
)
AS
BEGIN

SET NOCOUNT ON;

Set ANSI_WARNINGS OFF;

Select  pm.MenuName,
		p.ProgramName,
		pk.PackageName,
		cl.LevelName,
		pg.DisplayGameNo,
		pg.DisplayPartNo,
		ppi.CardCount * ppi.Qty as CardCount
From Package pk join PackageProductItems ppi on pk.PackageID = ppi.PackageID
Join POSMenuButtons pmb on pk.PackageID = pmb.PackageID
Join POSMenu pm on pmb.POSMenuID = pm.POSMenuID
Join ProductItem pi on ppi.ProductItemID = pi.ProductItemID
Join ProgramGames pg on ppi.GameCategoryID = pg.GameCategoryID
Join Program p on pg.ProgramID = p.ProgramID
Join CardLevel cl on ppi.CardLevelID = cl.CardLevelID
Where pmb.POSMenuID = @POSMenuID
And pg.ProgramID = @ProgramID
And pk.OperatorID = @OperatorID
Group By pm.MenuName, p.ProgramName, pk.PackageName, pg.DisplayGameNo, pg.DisplayPartNo, cl.LevelName, ppi.CardCount, ppi.Qty



SET NOCOUNT OFF

End

GO

