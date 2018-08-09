USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryNightly]    Script Date: 01/30/2014 09:07:29 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventoryNightly]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventoryNightly]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventoryNightly]    Script Date: 01/30/2014 09:07:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptInventoryNightly] 
-- =============================================
-- Author:		Travis M. Pollock
-- Description:	<Inventory levels for inventory products that were
--               used on the current date>
-- =============================================
	@OperatorID	AS INT
AS
	
SET NOCOUNT ON

Declare @CurrentDate Date

Set @CurrentDate = dbo.GetCurrentGamingDate()

Declare @Results table
(
	SerialNumber nvarchar(30),
	LocationName nvarchar(64),
	ItemName	nvarchar(64),
	CurrentCount int
)
Insert into @Results
(
	SerialNumber,
	LocationName,
	ItemName,
	CurrentCount
)
SELECT ii.iiSerialNo
	, il.ilInvLocationName
	, pdi.ItemName
	, SUM(CONVERT(bigint, itd.ivdDelta)) as CurrentCount -- current count
FROM InvTransaction it
	JOIN InvTransactionDetail itd ON (it.ivtInvTransactionID = itd.ivdInvTransactionID)
	JOIN InventoryItem ii ON (it.ivtInventoryItemID = ii.iiInventoryItemID)
	JOIN ProductItem pdi ON (ii.iiProductItemID = pdi.ProductItemID)
	JOIN InvLocations il on (il.ilInvLocationID = itd.ivdInvLocationID)
WHERE (pdi.OperatorID = @OperatorID OR @OperatorID = 0)
	AND ii.iiRetiredDate IS NULL
	And ilInvLocationTypeID in (1, 2)
	And Convert(Date, ii.iiLastIssueDate) = @CurrentDate
GROUP BY pdi.ItemName, ii.iiSerialNo, il.ilInvLocationName
Order By ilInvLocationName, pdi.ItemName, ii.iiSerialNo

Select *
From @Results

Set Nocount Off



GO

