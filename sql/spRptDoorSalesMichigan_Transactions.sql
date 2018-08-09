USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSalesMichigan_Transactions]    Script Date: 06/23/2011 09:00:26 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSalesMichigan_Transactions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSalesMichigan_Transactions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSalesMichigan_Transactions]    Script Date: 06/23/2011 09:00:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE  [dbo].[spRptDoorSalesMichigan_Transactions] 
-- =============================================
-- Author:		Louis J. Landerman
-- Description:	<>
-- BJS - 06/23/2011   DE8221 missing floor sales.  
--					  Allow rpt file to retain this sp, but use spRptDoorSales instead. 
-- 2011.08.05 bjs: US1902 add prod group param
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT,
	@ProductGroupID as int

AS
	
SET NOCOUNT ON
exec spRptDoorSales_Transactions @OperatorID, @StartDate, @EndDate, @Session, @ProductGroupID;
SET NOCOUNT OFF


GO


