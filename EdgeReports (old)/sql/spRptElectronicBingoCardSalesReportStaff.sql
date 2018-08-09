USE [Daily]
GO
/****** Object:  StoredProcedure [dbo].[spRptElectronicBingoCardSalesReportStaff]    Script Date: 06/14/2012 13:57:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER procedure [dbo].[spRptElectronicBingoCardSalesReportStaff]
@OperatorID int,
@Session int,
@StartDate datetime
--=============================================================================
-- 2012.06.14 jkn TA11171 Remove the CBB Paper Sales from the electronic report
--=============================================================================
as
begin	

	declare @Results table
	(
		rrID int,
		productItemName nvarchar(260),
		noOfCards int,		
		packageQuantity int,
		packagePrice money,
		staffID int,
		lastName nvarchar(260),
		firstName nvarchar(260),
		packageVoidedQty int,
		cardStartNo int,
		cardEndNo int
	);
      declare @ItemQty table
	(
	    productItemName nvarchar(260),
	    quantity int,
	    packagePrice money,
	    staffId int
	);

		
	insert into @Results
	( productItemName
	, packagePrice
	, noOfCards
	, staffID
	, cardStartNo
	, cardEndNo
	, packageQuantity
	, packageVoidedQty	)	
	select
	      rdi.ProductItemName
	    , rdi.Price
	    , count(bcd.bcdCardNo)
	    , rr.StaffID
	    , min(bcd.bcdCardNo)
	    , max(bcd.bcdCardNo)
	    , 0
	    , 0
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
	and rdi.CardMediaId = 1
	and sgp.IsContinued = 0
	group by rdi.ProductItemName, rdi.Price, rr.StaffID
	
    insert into @ItemQty
	select rdi.ProductItemName
	     , SUM( rd.Quantity* rdi.Qty)
	     , rdi.Price
	     , rr.StaffID
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
    group by rdi.ProductItemName, rdi.Price, rr.StaffID
		
	update r 
		set packageQuantity = i.quantity,
		    packagePrice = i.packagePrice
			
		from @Results r
		join @ItemQty i
		on r.productItemName = i.productItemName
		and r.packagePrice = i.packagePrice
		and r.staffID = i.staffId
		
	update r
	    set firstName = s.FirstName,
	        lastName = s.LastName
	    from @Results r
	    join Staff s
	    on s.StaffID = r.staffID;
	    
    -- Remove everything from the temp table
    delete @ItemQty
    
    -- calculate all of the voided items
    insert into @ItemQty
	select rdi.ProductItemName
	     , SUM( rd.Quantity* rdi.Qty)
	     , rdi.Price
	     , rr.StaffId
    from RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
    	join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID    			
	where 
    	rr.GamingDate = cast(convert(varchar(12), @StartDate, 101) AS smalldatetime)
        and rr.SaleSuccess = 1
    	and rr.OperatorID = @OperatorID
    		and voidedregisterreceiptid is not null
        and (@Session=0 or sp.GamingSession = @Session)	
    group by rdi.ProductItemName, rdi.Price, rr.StaffID
    
	update r 
		set packageVoidedQty = i.quantity
		from @Results r
    		join @ItemQty i on r.productItemName = i.productItemName
		        and r.packagePrice = i.packagePrice
		        and r.staffID = i.staffId
    
	select * from @Results;
end;
GO


