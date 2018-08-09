USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spTruncateDailyData]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spTruncateDailyData]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spTruncateDailyData]
--=============================================================================
-- 2016.06.30 jkn USD4756 Adding support for menus for specific devices
-- 2017.04.18 jkn: DE13575 Fixed issue with removing the daily menu device items
-- 2017.08.23 jkn: (Cannery Hotfix) The coupon that is being used needs to be
--	reset at the end of the day. If an operatorid is specified that denotes 
--	that an override was sent and we do not want to reset the coupons.
-- 2018.07.31 tmp: Delete from CompAward was failing. 
-- Delete was added so that a bounce back Coupon that is available every day does
-- not have to be created each day in the UI. 
--=============================================================================
	@OperatorID int = 0
WITH EXECUTE AS 'dbo'
AS
SET NOCOUNT ON

IF @OperatorID = 0
Begin
	TRUNCATE Table DailyStaffMenu
	TRUNCATE Table DailyGamesLink
	-- TRUNCATE Table DailyMenuDevice
	TRUNCATE Table DailyMenuButtons
	TRUNCATE Table DailyPackageProduct
	
    --DELETE FROM CompAward WHERE UsedCount = 0
    
    DELETE ca
	FROM CompAward AS ca
	LEFT JOIN RegisterDetail AS rd ON (rd.CompAwardId = ca.CompAwardId)
	WHERE ca.UsedCount = 0 AND rd.RegisterDetailId IS NULL
    
    UPDATE CompAutoAwardPlayerTally SET ToAwardCount = 0 WHERE CompId = 1
END
ELSE
BEGIN
	delete DailyPackageProduct
	from POSMenu p (nolock)
	join DailyMenuButtons dmb (nolock) on p.POSMenuID = dmb.POSMenuID
	join DailyPackageProduct dpp (nolock) on dmb.PackageID = dpp.PackageID
	where p.OperatorID = @OperatorID
	and dpp.PackageID not in (select dmb2.PackageID
		from POSMenu p2 (nolock)
		join DailyMenuButtons dmb2 (nolock) on p2.POSMenuID = dmb2.POSMenuID
		where p2.OperatorID <> @OperatorID)
		
	--delete DailyMenuDevice
	--from POSMenu p (nolock)
	--    join DailyMenuDevice dmd (nolock) on p.POSMenuId = dmd.POSMenuId
	--where p.OperatorId = @OperatorId -- DE13575

	delete DailyMenuButtons
	from POSMenu p (nolock)
	join DailyMenuButtons dmb (nolock) on p.POSMenuID = dmb.POSMenuID
	where p.OperatorID = @OperatorID

	declare @MaxSession int

	select @MaxSession = ISNULL(MAX(GamingSession), 0)
	from sessionplayed
	where GamingDate = dbo.GetCurrentGamingDate ()
	and OperatorID = @OperatorID
	and SessionEndDT IS NOT NULL

	delete DailyStaffMenu
	from POSMenu p (nolock)
	join DailyStaffMenu dsm (nolock) on p.POSMenuID = dsm.POSMenuID
	join SessionPlayed sp (nolock) on dsm.SessionPlayedID = sp.SessionPlayedID
	where p.OperatorID = @OperatorID
	and sp.GamingSession > @MaxSession
	and sp.SessionEndDT IS NULL

	delete DailyStaffMenu
	where OperatorID = @OperatorID
	and SessionPlayedID IS NULL

	delete DailyGamesLink
	from Program p (nolock)
	join ProgramGames pg (nolock) on p.ProgramID = pg.ProgramID
	join DailyGamesLink dgl (nolock) on pg.ProgramGamesID = dgl.ProgramGamesID
	where p.OperatorID = @OperatorID	
END

    TRUNCATE TABLE DailyPackNumber

SET NOCOUNT OFF

GO


