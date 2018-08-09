USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSalesMichigan]    Script Date: 06/22/2011 11:56:02 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSalesMichigan]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSalesMichigan]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSalesMichigan]    Script Date: 06/22/2011 11:56:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE  [dbo].[spRptDoorSalesMichigan] 
-- =============================================
-- Author:		Louis J. Landerman
-- Description:	<>
--
-- LJL - 02/03/2011 - Added Discounts to report
-- BJS - 03/07/2011   DE7730: add floor workers
-- BJS - 05/25/2011   US1809: cloned existing door sales to retain business logic. 
--                    (Format changes on rpt only.)  
-- BJS - 06/23/2011   DE8221 missing floor sales.  
--					  Allow rpt file to retain this sp, but use spRptDoorSales instead. 
--
-- =============================================
	@OperatorID	AS INT,
	@StartDate	AS DATETIME,
	@EndDate	AS DATETIME,
	@Session	AS INT,
	@ProductGroupID as int

AS
	
SET NOCOUNT ON
exec spRptDoorSales @OperatorID, @StartDate, @EndDate, @Session, @ProductGroupID;
SET NOCOUNT OFF

GO


