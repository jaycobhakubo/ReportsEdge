USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBusSalesByDate]    Script Date: 04/09/2019 12:31:00 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptBusSalesByDate]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptBusSalesByDate]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptBusSalesByDate]    Script Date: 04/09/2019 12:31:00 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure  [dbo].[spRptBusSalesByDate]     
   
 --=============================================    
 --Author:  Travis Pollock
 --Description: US5635 Bus Sales - Report for Colusa to report the sales by the bus that
 --                         brought the players to the casino.
 --                         Spend amount does not include Discounts & Coupons     
 -- 2018.04.05 tmp: Group by date
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
	GamingDate		datetime
	, PackageName	nvarchar(64)
	, PlayerID		int
	, PlayerMag		nvarchar(64)
	, PlayerName	nvarchar(64)
	, Spend			money
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

insert @Results
(
	GamingDate
	, PackageName		
	, PlayerID	
	, PlayerMag	
	, PlayerName	
	, Spend			
)
select  rr.GamingDate
		, (select top 1 bp.PackageName
			from @BusPlayers bp
			where bp.GamingDate = rr.GamingDate
					and bp.PlayerID = rr.PlayerID
					and bp.GamingSession = rd.SessionPlayedID)
--		, bp.PlayerID
		, rr.PlayerID
		, pmc.MagneticCardNo
		, p.FirstName + ' ' + p.LastName
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
from	
		--@BusPlayers bp 
		--join RegisterReceipt rr on bp.PlayerID = rr.PlayerID and bp.GamingDate = rr.GamingDate
		RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join Player p on rr.PlayerID = p.PlayerID
		left join PlayerMagCards pmc on p.PlayerID = pmc.PlayerID
where	rr.OperatorID = @OperatorID
		and rr.GamingDate >= cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
		and rr.GamingDate <= cast(convert(varchar(12), @EndDate, 101) AS smalldatetime)
		and rr.TransactionTypeID in (1, 3)
		and rr.SaleSuccess = 1
		and rd.VoidedRegisterReceiptID is null
group by rr.GamingDate
--	, bp.PackageName
--	, bp.PlayerID
	, rr.PlayerID
	, rr.TransactionTypeID
	, pmc.MagneticCardNo
	, p.FirstName
	, p.LastName
	, rd.SessionPlayedID;
	
select * 
from @Results 
where PackageName is not null
order by GamingDate, PackageName, PlayerName;   

set nocount off
   
GO

