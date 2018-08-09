USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptProducts]    Script Date: 04/16/2014 12:03:27 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptProducts]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptProducts]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptProducts]    Script Date: 04/16/2014 12:03:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- 2014.04.16 tmp: DE9802 - Do not return the 'Unknown' products.
------------------------------------------------

CREATE PROCEDURE [dbo].[spRptProducts]
	@OperatorID as int
AS
BEGIN
	SET NOCOUNT ON;
 SELECT PrI.OperatorID, PrI.ItemName, PG.GroupName, PT.ProductType, SS.Source, PrI.IsActive
 FROM   ProductItem PrI (nolock)  
JOIN ProductType PT ON PrI.ProductTypeID = PT.ProductTypeID 
JOIN SalesSource SS ON PrI.SalesSourceID = SS.SalesSourceID 
LEFT JOIN ProductGroup PG ON PrI.ProductGroupID = PG.ProductGroupID
Where PrI.OperatorID = @OperatorID
And PrI.ProductItemID > 0 -- DE9802
    
END












GO

