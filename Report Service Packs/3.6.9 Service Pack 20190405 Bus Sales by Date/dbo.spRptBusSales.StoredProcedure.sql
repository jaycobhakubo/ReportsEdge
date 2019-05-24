USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBusSales]    Script Date: 04/09/2019 12:30:51 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBusSales]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBusSales]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBusSales]    Script Date: 04/09/2019 12:30:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE procedure  [dbo].[spRptBusSales]     
   
 --=============================================    
 --Author:  Travis Pollock
 --Description: US5635 Bus Sales - Report for Colusa to report the sales by the bus that
 --                         brought the players to the casino.
 --                         Spend amount does not include Discounts & Coupons     
 -- 2018.09.25 tmp: Added Discounts and Coupons.
 --=============================================    
  
	@OperatorID	as int,    
	@StartDate  as datetime,    
	@EndDate	as datetime    
as   

-->>>>>>>>>>>>>>>>>>TEST START<<<<<<<<<<<<<<<<<<  
--declare  
--@OperatorID  as int,  
--@StartDate  as datetime,  
--@EndDate  as datetime
  
--set @OperatorID = 1   
--set @StartDate = '03/18/2014 00:00:00'  
--set @EndDate = '03/18/2014 00:00:00'  
--TEST END  
-->>>>>>>>>>>>>>>>>>>>TEST END<<<<<<<<<<<<<<<<<<<<<
     
set nocount on    

declare @Results table
(
	PackageName		nvarchar(64)
	, PlayerID		int
	, PlayerMag		nvarchar(64)
	, PlayerName	nvarchar(64)
	, Address1		nvarchar(64)
	, Address2		nvarchar(64)
	, City			nvarchar(64)
	, State			nvarchar(64)
	, Zip			nvarchar(64)
	, Spend			money
	, TransCount	int
)
-- Get the players by Bus
declare @BusPlayers table
(
	GamingDate	datetime
	, GamingSession int
	, PackageName nvarchar(max)
	, PlayerID	int
)
insert into @BusPlayers
(
	GamingDate
	, GamingSession
	, PackageName
	, PlayerID
)
select	rr.GamingDate
		, rd.SessionPlayedID
		, rd.PackageName
		, rr.PlayerID
from	RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)  
		and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)  
		and rr.SaleSuccess = 1 
		and rd.VoidedRegisterReceiptID is null
		and (	rd.PackageName like 'Bus 2%'
				or rd.PackageName like 'Bus D%'
			)
		and rr.PlayerID is not null
group by rr.GamingDate, rd.SessionPlayedID, rd.PackageName, rr.PlayerID;

-- Get the player spend
insert @Results
(
	PackageName		
	, PlayerID	
	, PlayerMag	
	, PlayerName	
	, Address1		
	, Address2
	, City			
	, State			
	, Zip			
	, Spend			
	, TransCount	
)
select  
--		bp.PackageName
--		, bp.PlayerID
		(select top 1 bp.PackageName
			from @BusPlayers bp
			where bp.GamingDate = rr.GamingDate
					and bp.PlayerID = rr.PlayerID
					and bp.GamingSession = rd.SessionPlayedID)
		, rr.PlayerID
		, pmc.MagneticCardNo
		, p.FirstName + ' ' + p.LastName
		, a.Address1
		, a.Address2
		, a.City
		, a.State
		, a.Zip
		, case rr.TransactionTypeID 
			when 1 then (
							--(sum(isnull(rd.Quantity, 0) * isnull(rdi.Qty, 0) * isnull(rdi.Price, 0)))
							(sum(isnull(rd.Quantity, 0) * isnull(rd.PackagePrice, 0)))
							+ sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0)) 
							+ sum((isnull(rd.DiscountAmount, 0) * isnull(Quantity, 0)))
							+ sum(isnull(rd.DeviceFee, 0))
						)
			when 3 then (
							--(sum(isnull(rd.Quantity, 0) * isnull(rdi.Qty, 0) * isnull(rdi.Price, 0))) 
							(sum(isnull(rd.Quantity, 0) * isnull(rd.PackagePrice, 0)))
							+ sum(isnull(rd.SalesTaxAmt, 0) * isnull(rd.Quantity, 0)) 
							+ sum((isnull(rd.DiscountAmount, 0) * isnull(Quantity, 0)))
							+ sum(isnull(rd.DeviceFee, 0))
							
						) * -1
		end 
		, count(distinct rr.RegisterReceiptID)
from	
		--@BusPlayers bp 
		--join RegisterReceipt rr on bp.PlayerID = rr.PlayerID
		RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
--		left join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
		join Player p on rr.PlayerID = p.PlayerID
		left join Address a on p.AddressID = a.AddressID
		left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
		and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.TransactionTypeID in (1, 3)
		and rr.SaleSuccess = 1
		and rd.VoidedRegisterReceiptID is null
--		and rd.CompAwardID is null -- Do not include coupons
--		and rd.DiscountAmount is null -- Do not include discounts
group by 
	--bp.PackageName
	--, bp.PlayerID
	rr.GamingDate
	, rr.PlayerID
	, rd.SessionPlayedID
	, rr.TransactionTypeID
	, pmc.MagneticCardNo
	, p.FirstName
	, p.LastName
	, a.Address1
	, a.Address2
	, a.City
	, a.State
	, a.Zip;

select	PackageName		
		, PlayerID	
		, PlayerMag	
		, PlayerName	
		, Address1		
		, Address2
		, City			
		, State			
		, Zip			
		, sum(Spend) as Spend
		, sum(TransCount) as TransCount
from	@Results
where	PackageName is not null
group by PackageName, PlayerID, PlayerMag, PlayerName, Address1, Address2
	, City
	, State
	, Zip
order by PackageName, PlayerID;   

set nocount off
    


GO

