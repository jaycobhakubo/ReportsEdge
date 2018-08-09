USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationState]    Script Date: 09/30/2013 13:58:14 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spGetPlayerLocationState]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spGetPlayerLocationState]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spGetPlayerLocationState]    Script Date: 09/30/2013 13:58:14 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE proc [dbo].[spGetPlayerLocationState]
--=============================================================================
-- Author:		Karlo Camacho
-- Description: Retrieves a list of states from the address table
--
-- 2013.05.30 KC: Initial implementation
--=============================================================================
as
select distinct([state]) State  
from [address] 
where [state] is not null
and [state] <> ''
order by [state] asc

GO


