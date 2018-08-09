USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction]    Script Date: 05/22/2012 14:32:27 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryTransaction]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryTransaction]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryTransaction]    Script Date: 05/22/2012 14:32:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE PROCEDURE [dbo].[spRptInventoryTransaction] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@StaffID	as int	
AS
SET NOCOUNT ON

SET @EndDate = DateAdd(day, 1, @EndDate)

SELECT	FirstName AS StaffFirstName,
		LastName AS StaffLastName,
		StaffID 
FROM Staff
WHERE 
(@StaffID = 0 or StaffID = @StaffID)


SET NOCOUNT OFF






GO


