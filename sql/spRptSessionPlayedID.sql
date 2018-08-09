USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionPlayedID]    Script Date: 04/08/2015 10:55:52 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptSessionPlayedID]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptSessionPlayedID]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptSessionPlayedID]    Script Date: 04/08/2015 10:55:52 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:  Travis Pollock   
-- Description: Get the SessionPlayedID
------------------------------------------------

CREATE PROCEDURE [dbo].[spRptSessionPlayedID]
	@OperatorID as int,
	@StartDate as DateTime,
	@EndDate as DateTime,
	@Session as int
AS
BEGIN
	SET NOCOUNT ON;

Select	SessionPlayedID,
		GamingDate,
		GamingSession
From SessionPlayed sp join Operator o on sp.OperatorID = O.OperatorID
join Address a on o.AddressID = a.AddressID 
Where sp.OperatorID = @OperatorID
And sp.GamingDate >= @StartDate
And sp.GamingDate <= @EndDate
And sp.GamingSession = @Session
And IsOverridden = 0
And (a.State = 'ND' or a.State = 'North Dakota')

End

GO

