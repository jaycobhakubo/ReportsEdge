USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationZip]    Script Date: 09/30/2013 13:58:34 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spGetPlayerLocationZip]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spGetPlayerLocationZip]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationZip]    Script Date: 09/30/2013 13:58:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [dbo].[spGetPlayerLocationZip]
--=============================================================================
-- Author:		Karlo Camacho
-- Description: Retrieves a list of postal codes from the address table
--
-- 2013.05.30 KC: Initial implementation
--=============================================================================
as
select distinct(Zip) Zip 
from [address]
where Zip is not null
and Zip <> ''
order by Zip asc

GO


