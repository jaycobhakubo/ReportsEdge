USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpendByDate]    Script Date: 08/09/2017 13:12:39 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPlayerSpendByDate]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPlayerSpendByDate]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPlayerSpendByDate]    Script Date: 08/09/2017 13:12:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptPlayerSpendByDate]
-- ============================================================================
-- Author:		FortuNet
-- Description:	Returns the player spend information
--
-- 20170809 tmp: Copy of the Player Spend report change the order of displayed information.
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as smalldatetime,
	@EndDate as smallDatetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
declare @spendTable table (
    xPlayerId int
    ,xTotalSpend money
    ,xAvgSpend money)
    
;with cte_PlayerSpend
	(
		PlayerID,
		RegisterReceiptId,
		Spend
	)
	as
		(
			select  rr.PlayerID,
					rr.RegisterReceiptID,
					case rr.TransactionTypeID 
						when 1 then ((sum(isnull(rd.PackagePrice, 0) * isnull(rd.Quantity, 0))) + (sum(isnull(rd.DiscountAmount, 0) * isnull(rd.Quantity, 0))) + (sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0))))
						when 3 then ((sum(isnull(rd.PackagePrice, 0) * isnull(rd.Quantity, 0))) + (sum(isnull(DiscountAmount, 0) * isnull(Quantity, 0))) + (sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0)))) * -1
					end 
			from	RegisterReceipt rr
					join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
			where	rr.OperatorID = @OperatorID
					and rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
					and rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
					and rr.TransactionTypeID in (1, 3)
					and rr.PlayerID is not null
					and rd.VoidedRegisterReceiptID is null
			group by rr.RegisterReceiptID, rr.PlayerID, rr.TransactionTypeID
		)
		,	cte_PlayerSpendDeviceFees
			(
				PlayerID,
				RegisterReceiptID,
				GamingDate,
				Spend
			)
			as
				(
					select  ctePS.PlayerID,
						ctePS.RegisterReceiptID,
						rr.GamingDate,
						isnull(ctePS.Spend, 0) + isnull(rr.DeviceFee, 0)
					from	RegisterReceipt rr
						join cte_PlayerSpend ctePS on rr.RegisterReceiptID = ctePS.RegisterReceiptId
				)			
				select	pmc.MagneticCardNo,
					p.LastName,
					p.FirstName,
					GamingDate,
					sum(ctePSDF.spend) as Amount
				from	cte_PlayerSpendDeviceFees ctePSDF
					join Player p on ctePSDF.PlayerID = p.PlayerID
					left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
				group by ctePSDF.PlayerID, GamingDate, pmc.MagneticCardNo, p.LastName, p.FirstName
				order by p.LastName, p.FirstName

END;



GO

