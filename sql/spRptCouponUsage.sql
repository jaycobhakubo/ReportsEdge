USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCouponUsage]    Script Date: 06/08/2015 15:50:18 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCouponUsage]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCouponUsage]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCouponUsage]    Script Date: 06/08/2015 15:50:18 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		FortuNet
-- Create date: 04/24/2015 
-- Description:	US1848(P)/US3962(C): Coupon Usage Report
-- =============================================
CREATE PROCEDURE [dbo].[spRptCouponUsage]
	@OperatorID int,
	@CompID int,
	@PlayerID int,
	@IsActive int
	
AS
BEGIN

	SET NOCOUNT ON;

if (@IsActive = null) set @IsActive = 0;

if (@IsActive = 0)
begin
	Select	c.CompID,
			c.CompName,
			c.Value,
			ca.AwardedDate,
			ca.AwardedCount,
			ca.UsedCount,
			(ca.AwardedCount - ca.UsedCount) as RemainingCount,
			ca.PlayerID,
			p.FirstName,
			p.LastName,
			pmc.MagneticCardNo
	From Comps c join CompAward ca on c.CompID = ca.CompID
	join Player p on ca.PlayerID = p.PlayerID
	left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
	Where c.OperatorID = @OperatorID
	and (c.CompID = @CompID or @CompID = 0)	
	and (p.PlayerID = @PlayerID or @PlayerID = 0)
	Order By p.LastName, p.FirstName, ca.PlayerID
end
else
begin
--Get the current Date 
declare @currentdate smalldatetime
set @currentdate = GETDATE()
	Select	c.CompID,
			c.CompName,
			c.Value,
			ca.AwardedDate,
			ca.AwardedCount,
			ca.UsedCount,
			(ca.AwardedCount - ca.UsedCount) as RemainingCount,
			ca.PlayerID,
			p.FirstName,
			p.LastName,
			pmc.MagneticCardNo
	From Comps c join CompAward ca on c.CompID = ca.CompID
	join Player p on ca.PlayerID = p.PlayerID
	left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
	Where c.OperatorID = @OperatorID
	and (c.CompID = @CompID or @CompID = 0)	
	and (p.PlayerID = @PlayerID or @PlayerID = 0)
	and cast(@currentdate as datetime) between c.StartDate and c.ExpireDate
	Order By p.LastName, p.FirstName, ca.PlayerID

end




END

GO

