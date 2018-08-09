USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicBingoCardSalesReport]    Script Date: 03/01/2013 08:57:42 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptElectronicBingoCardSalesReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptElectronicBingoCardSalesReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicBingoCardSalesReport]    Script Date: 03/01/2013 08:57:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure [dbo].[spRptElectronicBingoCardSalesReport]
@OperatorID int,
@Session int,
@StartDate datetime
as begin
--=============================================================================
-- 2012.06.14 jkn TA11171 Remove the CBB Paper Sales from the electronic report
-- 2013.02.28 knc TA11572|DE10816 - Replaying a game in the session causes the number of cards sold to be incorrect in some of the reports.
--=============================================================================


-->>>>>>>>>>>>>>>TEST<<<<<<
--declare
--@OperatorID int,
--@Session int,
--@StartDate datetime

--set @OperatorID = 1
--set @Session = 1
--set @StartDate = '2/7/2013 00:00:00'

--begin 
-->>>>>>>>>>>>><<<<<<<<<




	declare @Results table
	(		
		productItemName nvarchar(260),
		noOfCards int,		
		packageQuantity int,
		packagePrice money,
		packageVoidedQty int,
		cardStartNo int,
		cardEndNo int
	);
	
   declare @ItemQty table
	(
	    productItemName nvarchar(260),
	    quantity int,
	    packagePrice money
	);
	
	
	
	select
		   distinct(bcd.bcdCardNo),
	      rdi.ProductItemName
	    , rdi.Price,
	  
	  --  , bcd.bcdCardNo
	  --  , bcd.bcdCardNo
	    rr.TransactionNumber 
	into #TempA
	from BingoCardDetail bcd 
	    join BingoCardHeader bch on bcd.bcdMasterCardNo = bch.bchMasterCardNo 
					    and bcd.bcdSessionGamesPlayedID = bch.bchSessionGamesPlayedID
	    join SessionGamesPlayed sgp on bch.bchSessionGamesPlayedID = sgp.SessionGamesPlayedID
	    join RegisterDetailItems rdi on bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID
	    join RegisterDetail rd on rd.RegisterDetailID = rdi.RegisterDetailID
	    join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
	where sgp.SessionGamesPlayedID in (select sgp.SessionGamesPlayedID from SessionGamesPlayed sgp
		join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
		join RegisterDetail rd on sp.SessionPlayedID = rd.SessionPlayedID
		join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
		where rr.GamingDate = cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
		and rr.OperatorID = @OperatorID
		and (@Session=0 or sp.GamingSession = @Session)
		and RR.SaleSuccess = 1
			and isnull(voidedregisterreceiptid,0) = 0)
	and bch.bchCardVoided = 0
	and rdi.CardMediaID = 1
	and sgp.IsContinued = 0
	--and ProductItemName like '%Bonanza%'
	--and rdi.ProductTypeID != 16
	--group by rdi.ProductItemName, rdi.Price	
	
	
	
	insert into @Results
	( productItemName
	, packagePrice
	, noOfCards
	, cardStartNo
	, cardEndNo
	, packageQuantity
	, packageVoidedQty	)	
		select
	      ProductItemName
	    , Price
	    , count(bcdCardNo)
	    , min(bcdCardNo)
	    , max(bcdCardNo)
	    , 0
	    , 0 from #TempA 
	group by ProductItemName, Price	
	--select
	--      rdi.ProductItemName
	--    , rdi.Price
	--    , count(bcd.bcdCardNo)
	--    , min(bcd.bcdCardNo)
	--    , max(bcd.bcdCardNo)
	--    , 0
	--    , 0
	--from BingoCardDetail bcd 
	--    join BingoCardHeader bch on bcd.bcdMasterCardNo = bch.bchMasterCardNo 
	--				    and bcd.bcdSessionGamesPlayedID = bch.bchSessionGamesPlayedID
	--    join SessionGamesPlayed sgp on bch.bchSessionGamesPlayedID = sgp.SessionGamesPlayedID
	--    join RegisterDetailItems rdi on bch.bchRegisterDetailItemID = rdi.RegisterDetailItemID
	--    join RegisterDetail rd on rd.RegisterDetailID = rdi.RegisterDetailID
	--    join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
	--where sgp.SessionGamesPlayedID in (select sgp.SessionGamesPlayedID from SessionGamesPlayed sgp
	--	join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
	--	join RegisterDetail rd on sp.SessionPlayedID = rd.SessionPlayedID
	--	join RegisterReceipt rr on rd.RegisterReceiptID = rr.RegisterReceiptID
	--	where rr.GamingDate = cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
	--	and rr.OperatorID = @OperatorID
	--	and (@Session=0 or sp.GamingSession = @Session)
	--	and RR.SaleSuccess = 1
	--		and isnull(voidedregisterreceiptid,0) = 0)
	--and bch.bchCardVoided = 0
	--and rdi.CardMediaID = 1
	--and sgp.IsContinued = 0
	----and rdi.ProductTypeID != 16
	--group by rdi.ProductItemName, rdi.Price	
	
	drop table #TempA 

	
	insert into @ItemQty
		select rdi.ProductItemName,SUM( rd.Quantity* rdi.Qty),
	       rdi.Price 
	from RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID    			

	where 
	rr.GamingDate = cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
	and RR.SaleSuccess = 1
	and rr.OperatorID = @OperatorID
		and isnull(voidedregisterreceiptid,0) = 0
	and (@Session=0 or sp.GamingSession = @Session)	
	group by rdi.ProductItemName, rdi.Price
	
	--select * from @ItemQty  where productItemName like '%Bonan%' 
	--select * from @Results 
	
	update r 
		set packageQuantity = i.quantity,
		    packagePrice = i.packagePrice			
		from @Results r
		join @ItemQty i
		on r.productItemName = i.productItemName
		and r.packagePrice = i.packagePrice
	
	delete from @ItemQty
	
	insert into @ItemQty
		select rdi.ProductItemName,SUM( rd.Quantity* rdi.Qty),
	       rdi.Price 
	from RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID    			

	where 
	rr.GamingDate = cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
	and RR.SaleSuccess = 1
	and rr.OperatorID = @OperatorID
		and voidedregisterreceiptid is not null
	and (@Session=0 or sp.GamingSession = @Session)	
	group by rdi.ProductItemName, rdi.Price
		
	update r 
		set packageVoidedQty = i.quantity
		from @Results r
		join @ItemQty i
		on r.productItemName = i.productItemName
		and r.packagePrice = i.packagePrice
		
		
	select * from @Results;
end;















GO


