USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptVersionInfo]    Script Date: 10/03/2011 09:49:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptVersionInfo]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptVersionInfo]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptVersionInfo]    Script Date: 10/03/2011 09:49:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spRptVersionInfo]
--(
    --@OperatorID INT
--)
AS
SET NOCOUNT ON

SELECT Version AS VersionInfo
FROM VersionInfo;

SET NOCOUNT OFF




GO


