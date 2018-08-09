USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Transactions]    Script Date: 07/24/2012 09:07:29 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptDoorSales_Transactions]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptDoorSales_Transactions]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptDoorSales_Transactions]    Script Date: 07/24/2012 09:07:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE  [dbo].[spRptDoorSales_Transactions] 
-- ============================================================================
-- Author:		Louis J. Landerman
-- Description:	<>
-- 2011.08.05 bjs: US1902 add prod group param
-- 2012.02.17 jkn: DE10142 count failed sales as transactions
-- 2012.07.24 jkn: DE10626 calculate the tax correctly for a package that
--  contains multiple products
-- ============================================================================
	@OperatorID	as int,
	@StartDate	as datetime,
	@EndDate	as datetime,
	@Session	as int,
	@ProductGroupID as int

as
	
set nocount on

-- FIX US1902
-- Tricky bits here; the transaction saves the group name at the time of the transaction instead of a FK to the product group...
declare @groupName nvarchar(64); set @groupName = '';
select @groupName = GroupName from ProductGroup where ProductGroupID = @ProductGroupID;

-- DE7269 - Door sales not counting transactions with no details.
declare @FirstTransaction as int
declare @LastTransaction as int
declare @TransactionCount as int
declare @SalesTax as money

--declare @DoorSales table 
--(
--	transactionNumber int,
--	salesTax money,
--	groupName nvarchar(64)
--);

---- us1902
--insert into @DoorSales (transactionNumber, salesTax, groupName)
--SELECT	
--    ISNULL((rr.TransactionNumber), 0),
----	ISNULL((rd.SalesTaxAmt * rd.Quantity), 0),
--	case when rdi.RegisterDetailItemId in (select top 1 (rdi2.RegisterDetailItemId) from RegisterDetailItems rdi2 where rdi2.RegisterDetailId = rdi.RegisterDetailId)
--	    then ISNULL(rd.SalesTaxAmt, 0) * rd.Quantity
--	    else 0 end,
--	isnull(rdi.GroupName, 'Unknown Group')
--FROM RegisterReceipt rr
--	JOIN RegisterDetail rd ON (rr.RegisterReceiptID = rd.RegisterReceiptID)
--	join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
--	LEFT JOIN SessionPlayed sp ON (sp.SessionPlayedID = rd.SessionPlayedID)
--WHERE rr.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
--	AND rr.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)
--	AND rr.SaleSuccess = 1
--	AND rr.OperatorID = @OperatorID
--	AND (@Session = 0 or sp.GamingSession = @Session)	
--	AND rr.TransactionTypeID in (1, 3)
--	and (@ProductGroupID = 0 or @groupName = rdi.GroupName);


/*  US1902  
ORIGINAL CODE
*/
-- Sales and Returns
select	@FirstTransaction = isnull(min(rr.TransactionNumber), 0),
		@LastTransaction = isnull(max(rr.TransactionNumber), 0),
		@TransactionCount = count(distinct rr.TransactionNumber),
		@SalesTax = isnull(sum(rd.SalesTaxAmt * rd.Quantity), 0)
from RegisterReceipt rr
	join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
	join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
	left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
	and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
	and rr.OperatorID = @OperatorID
	and (@Session = 0 or sp.GamingSession = @Session)	
	and rr.TransactionTypeID in (1, 3)
	and (@ProductGroupID = 0 or @groupName = rdi.GroupName)
	and rdi.RegisterDetailItemId in (select top 1 (rdi2.RegisterDetailItemId) from RegisterDetailItems rdi2 where rdi2.RegisterDetailId = rdi.RegisterDetailId); --DE10626
	
-- Voids
select	@FirstTransaction = case when min(rr.TransactionNumber) < @FirstTransaction then min(rr.TransactionNumber) else @FirstTransaction end,
		@LastTransaction = case when max(rr.TransactionNumber) > @LastTransaction then max(rr.TransactionNumber) else @LastTransaction end,
		@TransactionCount = count(distinct rr.TransactionNumber) + @TransactionCount,
		@SalesTax = @SalesTax - isnull(sum(rd.SalesTaxAmt * rd.Quantity), 0)
from RegisterReceipt rr
	join RegisterDetail rd on rr.RegisterReceiptID = rd.VoidedRegisterReceiptID
	join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
	left join SessionPlayed sp on (sp.SessionPlayedID = rd.SessionPlayedID)
where rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) as smalldatetime)
	and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) as smalldatetime)
	and rr.OperatorID = @OperatorID
	and (@Session = 0 or sp.GamingSession = @Session)	
	and rr.TransactionTypeID = 2
	and (@ProductGroupID = 0 or @groupName = rdi.GroupName)
	and rdi.RegisterDetailItemId in (select top 1 (rdi2.RegisterDetailItemId) from RegisterDetailItems rdi2 where rdi2.RegisterDetailId = rdi.RegisterDetailId); --DE10626

select @FirstTransaction as FirstTransaction
    , @LastTransaction as LastTransaction
    , @TransactionCount as TransactionCount
    , @SalesTax as SalesTax

set nocount off







GO

