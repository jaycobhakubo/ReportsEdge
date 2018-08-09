USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPageFooter]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPageFooter]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spRptPageFooter]
AS
SET NOCOUNT ON

SELECT Version AS VersionInfo
FROM VersionInfo;

SET NOCOUNT OFF




GO


