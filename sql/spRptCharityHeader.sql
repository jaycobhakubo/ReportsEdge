USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCharityHeader]    Script Date: 10/03/2014 09:05:35 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptCharityHeader]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptCharityHeader]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptCharityHeader]    Script Date: 10/03/2014 09:05:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE  [dbo].[spRptCharityHeader] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Reports the charity data>
-- 20141001 tmp: DE12067 & DE12068 Added @OperatorID parameter and @OperatorID to the where condition.
--				 The charity name was not correct when multiple operators played on the same gaming date.	
-- =============================================
	
		@Session as Int,
		@StartDate as DateTime,
		@EndDate as DateTime,
		@OperatorID as Int  --DE12067

AS
	
SET NOCOUNT ON

-- Testing
-- Declare @Session as Int,
--		@StartDate as DateTime,
--		@EndDate as DateTime
	
		
--Set @Session = 1
--Set @StartDate = '08/08/2013'
--Set @EndDate = '08/08/2013'

Select	c.Name,
		c.LicenseNumber,
		c.TaxPayerId,
		a.Address1,
		a.Address2,
		a.City,
		a.State,
		a.Zip
From Charity c join Address a on (a.AddressID = c.AddressId)
Join SessionPlayed sp on (sp.CharityId = c.CharityId)
Where  sp.OperatorID = @OperatorID  --DE12067 & DE12068
And sp.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)      
And sp.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
And sp.GamingSession = @Session or @Session = 0


Set NoCount Off















GO

