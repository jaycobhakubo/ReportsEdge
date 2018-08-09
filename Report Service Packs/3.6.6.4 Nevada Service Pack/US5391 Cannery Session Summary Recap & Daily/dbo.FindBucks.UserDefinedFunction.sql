USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindBucks]    Script Date: 08/14/2017 16:44:37 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FindBucks]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FindBucks]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindBucks]    Script Date: 08/14/2017 16:44:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE function [dbo].[FindBucks]
(
	@OperatorID		AS INT,
	@StartDate		AS DATETIME,
	@EndDate		AS DATETIME,
	@Session		AS INT
)
returns table
as 
return
(
	with FindBucks (GamingDate, GamingSession, BucksAmount) as
	(
		select	rr.GamingDate,
				sp.GamingSession,
				case when rr.TransactionTypeId = 1 then sum((rd.Quantity * rdi.Qty) * rdi.Price)  
					 when rr.TransactionTypeId = 3 then sum((-1 * rd.Quantity * rdi.Qty) * rdi.Price)  
				end as BucksAmount
		from	RegisterReceipt rr 
				join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
				join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
				left join SessionPlayed sp ON sp.SessionPlayedID = rd.SessionPlayedID
		where	rr.OperatorID = @OperatorID
				and rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
				and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime) 
				and ( @Session = 0 
					  or sp.GamingSession = @Session
					 )  
				and rdi.ProductItemName like '%buck%'
				and rr.SaleSuccess = 1
				and ( rr.TransactionTypeID = 1		-- Sale
					  or rr.TransactionTypeId = 3   -- Return
					 )
				and rd.VoidedRegisterReceiptID is null
		Group By rr.GamingDate, sp.GamingSession, rr.TransactionTypeID
	)
	select	GamingDate,
			GamingSession,
			sum(isnull(BucksAmount, 0)) as BucksAmount
	from	FindBucks
	group by GamingDate, GamingSession
)



GO

