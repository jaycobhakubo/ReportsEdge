USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptValidations]    Script Date: 08/17/2017 12:30:57 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptValidations]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptValidations]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptValidations]    Script Date: 08/17/2017 12:30:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create proc [dbo].[spRptValidations]

@OperatorID	Int,	
@StartDate	DateTime,
@EndDate	DateTime,
@Session	int  

as

set nocount on    

declare @Results table
(
	SessionPlayedID	int,
	RegisterDetailID int,
	PackageName		nvarchar(64),
	QtyValidated	int,
	ValidationCount	int,
	ValidationOverride int,
	ValidationPrice	money,
	IsElectronic	int
);		

with cteValidation 
(
	RegisterDetailID, 
	RegisterReceipID, 
	ProductItemName, 
	Validated, 
	ValidatedCount, 
	IsElectronic
)
as
(
	select	distinct rdi.RegisterDetailID,
			rd.RegisterReceiptID,
			rdi.ProductItemName,
			Validated,
			case when CardMediaID = 1 then (sum(Qty * CardCount) / 6) * Quantity
				 else sum(Quantity)
			end,
			case when CardMediaID = 1 then 1 
				 else 0
			end as IsElectronic  
	from	RegisterDetailItems rdi
			join RegisterDetail rd on rdi.RegisterDetailID = rd.RegisterDetailID
			join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
			left join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
	where	rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
			and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
			and rr.SaleSuccess = 1  
			and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
			and rr.OperatorID = @OperatorID  
			and (@Session = 0 or sp.GamingSession = @Session)  
			and rd.VoidedRegisterReceiptID is null
			and rr.SaleSuccess = 1
			and rd.DiscountTypeID is null -- Do not include function discounts
			and rd.CompAwardID is null -- Removed coupon items
			and rdi.Validated is not null
	group by rdi.ProductItemName,
			rd.RegisterReceiptID,
			rdi.RegisterDetailID,
			Validated,
			CardMediaID,
			Quantity
)
,
cteValidationPrice 
(
	RegisterReceiptID, 
	SessionPlayedID, 
	PackagePrice
)
as
(
	select	rd.RegisterReceiptID,
			rd.SessionPlayedID,
			PackagePrice
	from	RegisterDetail rd
			join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
			left join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
	where	rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
			and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
			and rr.SaleSuccess = 1  
			and (rr.TransactionTypeID = 1 or rr.TransactionTypeId = 3) -- Sale Or Returns  
			and rr.OperatorID = @OperatorID  
			and (@Session = 0 or sp.GamingSession = @Session)  
			and rd.VoidedRegisterReceiptID is null
			and rr.SaleSuccess = 1
			and PackageName = 'Validation'
	group by rd.RegisterReceiptID,
			rd.SessionPlayedID,
			PackagePrice
)
insert into @Results
(
	SessionPlayedID,
	RegisterDetailID,
	PackageName,
	QtyValidated,
	ValidationCount,
	ValidationOverride,
	ValidationPrice,
	IsElectronic
)
select	ctp.SessionPlayedID,
		ctv.RegisterDetailID,
		rd.PackageName,
		case when rr.TransactionTypeId = 1 then rd.Quantity  
			when rr.TransactionTypeId = 3 then -1 * rd.Quantity  
		end as QtyValidated,
		case when rr.TransactionTypeId = 1 then sum(ctv.ValidatedCount)  
			when rr.TransactionTypeId = 3 then sum(-1 * ctv.ValidatedCount)  
		end as QtyValidationCount,
		case when p.ValidationOverride = 1 then p.ValidationCount
			else null
		end as ValidationOverride,
		ctp.PackagePrice,
		IsElectronic
from	cteValidation ctv
		left join cteValidationPrice ctp on ctv.RegisterReceipID = ctp.RegisterReceiptID
		join SessionPlayed sp on ctp.SessionPlayedID = sp.SessionPlayedID
		join RegisterDetail rd on ctv.RegisterDetailID = rd.RegisterDetailID
		left join Package p on rd.PackageName = p.PackageName and p.IsActive = 1
		join RegisterReceipt rr on ctv.RegisterReceipID = rr.RegisterReceiptID
group by ctp.SessionPlayedID,
		ctv.RegisterDetailID,
		rd.PackageName,
		ctp.PackagePrice,
		rr.TransactionTypeID,
		IsElectronic,
		p.ValidationOverride,
		p.ValidationCount,
		rd.Quantity;
		
with cte_ValidationByType 
(
	SessionPlayedID, 
	ElectronicVal, 
	PaperVal
)
as
(		
select	r.SessionPlayedID,
		case when r.IsElectronic = 1 then isnull(sum(case when ValidationOverride is not null then QtyValidated * ValidationOverride * isnull(ValidationPrice, 0)
														  else ValidationCount * isnull(ValidationPrice, 0)
													 end), 0)
			 else 0
		end,
		case when r.IsElectronic = 0 then isnull(sum(case when ValidationOverride is not null then QtyValidated * ValidationOverride * isnull(ValidationPrice, 0)
														  when ValidationOverride is null and PackageName like '%Rainbow%' then QtyValidated * 2 * ValidationPrice		
														  else ValidationCount * isnull(ValidationPrice, 0)
													 end), 0)
			else 0
		end
from	@Results r
group by r.SessionPlayedID,
		r.IsElectronic
)
select  sp.GamingDate,
		sp.GamingSession,
		sum(ElectronicVal) as ElectronicVal,
		sum(PaperVal) as PaperVal,
		sum(ElectronicVal) + sum(PaperVal) as Total
from	cte_ValidationByType vbt
		join SessionPlayed sp on vbt.SessionPlayedID = sp.SessionPlayedID 
group by sp.GamingDate, sp.GamingSession;

set nocount off


GO

