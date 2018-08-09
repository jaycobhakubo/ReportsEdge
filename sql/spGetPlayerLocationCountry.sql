USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationCountry]    Script Date: 09/30/2013 13:57:51 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spGetPlayerLocationCountry]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spGetPlayerLocationCountry]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationCountry]    Script Date: 09/30/2013 13:57:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [dbo].[spGetPlayerLocationCountry]
--=============================================================================
-- Author:		Karlo Camacho
-- Description: Retrieves a list of countries from the address table
--
-- 2013.05.30 KC: Initial implementation
--=============================================================================
as
select distinct(Country) Country 
from [address]
where Country is not null
and Country <> ''
order by Country asc

GO


