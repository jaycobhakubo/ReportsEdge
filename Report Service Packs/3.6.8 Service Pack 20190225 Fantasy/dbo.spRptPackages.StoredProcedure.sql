USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPackages]    Script Date: 02/25/2019 12:34:25 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPackages]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPackages]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPackages]    Script Date: 02/25/2019 12:34:25 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptPackages]
	@OperatorID int
AS
SET NOCOUNT ON

SELECT P.PackageID, P.PackageName, P.ChargeDeviceFee, P.ReceiptText, P.IsActive,
		PPI.IsTaxed, PPI.Price, PPI.Qty, PPI.PtsPerDollar, PPI.PtsToRedeem,
		PPI.PtsPerQuantity, PPI.CardCount, 
		ItemName, GroupName, ProductType, Source, Pr.IsActive,
		CardCutName = '',
		Multiplier, LevelName, CL.IsActive, CardMediaName, Cardtype, 
		GameTypeName, NumberofBalls, CardFaceLength, GCName
FROM Package P (nolock)
Join PackageProductItems PPI (nolock)  on P.PackageID = PPI.PackageID
Join ProductItem Pr (nolock) on PPI.ProductItemID = Pr.ProductItemID
Left Join CardLevel CL (nolock) on PPI.CardlevelID = CL.CardlevelID
Join GameTypes GT (nolock) on PPI.GameTypeID = GT.GametypeID
Join CardMedia CM (nolock) on PPI.CardMediaID = CM.CardMediaID
Join Cardtype CT (Nolock) on PPI.CardTypeID = CT.CardTypeID
Join gameCategory GC (nolock) on PPI.GameCategoryID = GC.GameCategoryID
JOIN ProductType PT ON Pr.ProductTypeID = PT.ProductTypeID 
JOIN SalesSource SS ON Pr.SalesSourceID = SS.SalesSourceID 
LEFT JOIN ProductGroup PG ON Pr.ProductGroupID = PG.ProductGroupID
where p.OperatorID = @OperatorID

SET NOCOUNT OFF
    


























GO

