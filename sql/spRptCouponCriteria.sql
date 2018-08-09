USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCouponCriteria]    Script Date: 06/09/2015 09:27:27 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCouponCriteria]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCouponCriteria]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCouponCriteria]    Script Date: 06/09/2015 09:27:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		FortuNet
-- Create date: 05/01/2015 
-- Description:	US1848(P)/US3961(C): Coupon Criteria Report
-- =============================================
CREATE PROCEDURE [dbo].[spRptCouponCriteria]
	@OperatorID int,
	@CompID int,
	@IsActive bit
AS
BEGIN

	SET NOCOUNT ON;
	
If @IsActive = 0	
	Begin
		Select	c.CompID,
				c.CompName,
				c.Value,
				c.StartDate,
				c.ExpireDate,
				c.MaxUsage,
				isnull(c.LastAwardedDate,
				(Select top 1 ca.AwardedDate From CompAward ca join Comps on C.CompID = ca.CompID order by ca.AwardedDate desc)) as LastAwardedDate
		From Comps c 
		Where c.OperatorID = @OperatorID
		and (c.CompID = @CompID or @CompID = 0)
	End
Else
	Begin
		Select	c.CompID,
			c.CompName,
			c.Value,
			c.StartDate,
			c.ExpireDate,
			c.MaxUsage,
			isnull(c.LastAwardedDate,
			(Select top 1 ca.AwardedDate From CompAward ca join Comps on C.CompID = ca.CompID order by ca.AwardedDate desc)) as LastAwardedDate
		From Comps c 
		Where c.OperatorID = @OperatorID
		and (c.CompID = @CompID or @CompID = 0)
		and c.ExpireDate >= GETDATE()
	End

END


GO

