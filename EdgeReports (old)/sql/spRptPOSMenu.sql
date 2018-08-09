USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPOSMenu]    Script Date: 01/24/2012 13:31:02 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPOSMenu]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPOSMenu]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPOSMenu]    Script Date: 01/24/2012 13:31:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- 1/25/12 bsb: DE9919
-- =============================================
CREATE PROCEDURE [dbo].[spRptPOSMenu]
	@OperatorID as int
AS
BEGIN
	SET NOCOUNT ON;

    select 
        MenuName, PageNumber, KeyNum, 
        PM.POSMenuID, PM.OperatorID, DiscountTypeName, FunctionName, PackageName, KeyText, 
		ReceiptText, Price, Qty, (Price * Qty) as ItemPrice, PtsPerDollar,
		PtsPerQuantity, PtsToRedeem, CardCount, IsTaxed, ItemName, PMB.PackageID, PlayerRequired, P.ChargeDeviceFee,
		D.Amount, D.PointsPerDollar,  Multiplier, LevelName
	from POSMenu PM 
	join POSMenuButtons PMB  on PM.POSMenuID = PMB.POSMenuID
	left join Package P  on PMB.PackageID = P.PackageID
	left join PackageProductItems PPI  on P.PackageID = PPI.PackageID 
	left join ProductItem PRI  on PPI.ProductitemID = PRI.ProductItemID 
	Left Join CardLevel CL  on PPI.CardlevelID = CL.CardlevelID
	Left Join Discounts D  on PMB.DiscountID = D.DiscountID
	left join DiscountTypes DT  on D.DiscountTypeID = DT.DiscountTypeID
	Left Join Functions F  on PMB.FunctionsID = F.FunctionsID
	Where PM.OperatorID = @OperatorID
	order by MenuName, PageNumber, KeyNum;
	
END;




GO

