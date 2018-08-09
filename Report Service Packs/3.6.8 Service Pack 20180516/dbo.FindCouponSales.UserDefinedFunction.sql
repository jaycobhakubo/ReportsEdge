USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindCouponSales]    Script Date: 05/16/2018 08:15:24 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FindCouponSales]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[FindCouponSales]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[FindCouponSales]    Script Date: 05/16/2018 08:15:24 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		FortuNet
-- Create date: 7/06/2015
-- Description:	Finds coupon sales usage.
-- Returns: table variable containing data ready for Crystal Reports (no null's in the money fields!).
-- 2018.05.16 tmp: Voided coupons were not being returned.
-- =============================================
CREATE FUNCTION [dbo].[FindCouponSales] 
(
	@OperatorID		AS INT,
	@StartDate		AS DATETIME,
	@EndDate		AS DATETIME,
	@Session		AS INT
)
--Set @OperatorID = 1
--Set @StartDate = '07/06/2015'
--Set @EndDate = '07/06/2015'
--Set @Session = 0	

Returns
@CouponSales table
( 
	GamingDate DateTime,
	GamingSession int,
	StaffID int,
	SoldFromMachineID int,
	GroupName nvarchar(64),
	CompID int,
	CouponName nvarchar(255),
	CouponValue money,
	QuantitySold int,
	TotalSales money,
	QuantityVoided int,
	VoidedSales money,
	QuantityNet int,
	NetSales money
)

As
Begin

Declare @CouponUsage table
( 
	GamingDate DateTime,
	GamingSession int,
	StaffID int,
	SoldFromMachineID int,
	CompID int,
	CouponName nvarchar(255),
	CouponValue money,
	QuantitySold int,
	TotalSales money,
	QuantityVoided int,
	VoidedSales money
)

-- Insert each coupon used 
Insert into @CouponUsage
(
	GamingDate,
	GamingSession,
	StaffID,
	SoldFromMachineID,
	CompID,
	CouponName,
	CouponValue, 
	QuantitySold,
	TotalSales
)
Select	rr.GamingDate,
		sp.GamingSession,
		rr.StaffID,
		rr.SoldFromMachineID,
		c.CompID,
		c.CompName,
		rd.PackagePrice,
		rd.Quantity,
		rd.Quantity * rd.PackagePrice
From	RegisterDetail rd join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
		Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
		Join CompAward ca on rd.CompAwardID = ca.CompAwardID
		Join Comps c on ca.CompID = c.CompID
where	rr.OperatorID = @OperatorID
		And rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		And rr.SaleSuccess = 1
		and rr.TransactionTypeID = 1
		And (@Session = 0 or sp.GamingSession = @Session)
		And rd.CompAwardID is not null

--- Insert Voided Coupons
Insert into @CouponUsage
(
	GamingDate,
	GamingSession,
	StaffID,
	SoldFromMachineID,
	CompID,
	CouponName,
	CouponValue, 
	QuantityVoided,
	VoidedSales
)
Select	rr.GamingDate,
		sp.GamingSession,
		rr.StaffID,
		rr.SoldFromMachineID,
		c.CompID,
		c.CompName,
		rd.PackagePrice,
		rd.Quantity,
		rd.Quantity * rd.PackagePrice
From	RegisterDetail rd join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
		Join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
		Join CompAward ca on rd.CompAwardID = ca.CompAwardID
		Join Comps c on ca.CompID = c.CompID
where	rr.OperatorID = @OperatorID
		And rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
		And rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
		--And rr.TransactionTypeID = 2  -- Sale Void
		and rr.TransactionTypeID = 1
		and rd.VoidedRegisterReceiptID is not null
		And rr.SaleSuccess = 1
		And (@Session = 0 or sp.GamingSession = @Session)
		And rd.CompAwardID is not null

-- Return the resultset
Insert into @CouponSales
Select	GamingDate,
		GamingSession,
		StaffID,
		SoldFromMachineID,
		GroupName = 'Coupons',
		CompID,
		CouponName,
		CouponValue, 
		Sum(isnull(QuantitySold, 0)) as QuantitySold,
		Sum(isnull (TotalSales, 0)) as TotalSales,
		SUM(isnull(QuantityVoided, 0)) as QauntityVoided,
		Sum(isnull(VoidedSales, 0)) as VoidedSales,
		SUM(isnull(QuantitySold, 0)) - SUM(isnull(QuantityVoided, 0)) as QuantityNet,
		SUM(isnull(TotalSales, 0)) - SUM(isnull(VoidedSales, 0)) as NetSales	
From @CouponUsage
Group By GamingDate, GamingSession, CompID, StaffID, SoldFromMachineID, CouponName, CouponValue

Return

End












GO

