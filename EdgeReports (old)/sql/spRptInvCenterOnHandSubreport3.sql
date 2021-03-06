USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvCenterOnHandSubreport3]    Script Date: 07/05/2011 08:54:06 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInvCenterOnHandSubreport3]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInvCenterOnHandSubreport3]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInvCenterOnHandSubreport3]    Script Date: 07/05/2011 08:54:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[spRptInvCenterOnHandSubreport3]
(	@OperatorID as int
)	
	 
AS

SET NOCOUNT ON;	

DECLARE @Serials AS TABLE
(
	shelfCount INT,
	playCount INT
);

INSERT INTO @Serials (ShelfCount)
SELECT COUNT(ii.iiSerialNo)
FROM InventoryItem ii
JOIN ProductItem p on ii.iiProductItemID = p.ProductItemID
WHERE (p.OperatorID = @OperatorID or @OperatorID = 0)
	AND p.ProductTypeID = 16
	AND ii.iiLastIssueDate IS NULL 
	AND ii.iiRetiredDate IS NULL;

UPDATE @Serials
SET PlayCount = (SELECT COUNT(ii.iiSerialNo)
				 FROM InventoryItem ii
				 JOIN ProductItem p on ii.iiProductItemID = p.ProductItemID
				 WHERE (p.OperatorID = @OperatorID or @OperatorID = 0)
					AND p.ProductTypeID = 16
					AND ii.iiLastIssueDate IS NOT NULL
					AND ii.iiRetiredDate IS NULL);

SELECT ISNULL(ShelfCount, 0) [Shelf], ISNULL(PlayCount, 0) [Play] 
FROM @Serials;

GO


