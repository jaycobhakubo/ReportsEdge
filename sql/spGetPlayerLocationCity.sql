USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationCity]    Script Date: 09/30/2013 13:57:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spGetPlayerLocationCity]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spGetPlayerLocationCity]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationCity]    Script Date: 09/30/2013 13:57:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [dbo].[spGetPlayerLocationCity]
--=============================================================================
-- Author:		Karlo Camacho
-- Description: Retrieves a list of cities from the address table
--
-- 2013.05.30 KC: Initial implementation
--=============================================================================
as
select distinct(City) City
from [address]
where City is not null
and City <> ''
order by City asc

GO


