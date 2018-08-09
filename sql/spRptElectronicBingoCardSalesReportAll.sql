USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicBingoCardSalesReportAll]    Script Date: 04/04/2012 17:23:04 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptElectronicBingoCardSalesReportAll]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptElectronicBingoCardSalesReportAll]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicBingoCardSalesReportAll]    Script Date: 04/04/2012 17:23:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure [dbo].[spRptElectronicBingoCardSalesReportAll]
@OperatorID int,
@Session int,
@StartDate datetime
as
begin

	declare @RegularBingo   varchar(60),
			@CrystalBingoHP varchar(60),
			@CrystalBingoQP varchar(60),
			@Slingo         varchar(60);
    
	declare @Results table
	(		
		groupName nvarchar(260),
		noOfCards int,		
		cardStartNo int,
		cardEndNo int,
		noOfCardsVoided int	
		
	);	
   
    declare @AllCardNumbers table
    (
        groupName nvarchar(260),
		cardNo int,
		sessionGamesPlayedID int,
		cardCount int,
		cardCountVoid int
		
    )
   
     declare @RegularVoids table
     ( 
        sessionGamesPlayedID int,
        cardCountVoid int
       )
    set @RegularBingo   =  'Regular Bingo';
    set @CrystalBingoHP =  'Crystal Ball Bingo(HP)';
    set @CrystalBingoQP =  'Crystal Ball Bingo(QP)';
    set @Slingo         =  'Slingo';
    
	
   insert into @AllCardNumbers(groupName ,
		cardNo ,
		sessionGamesPlayedID
		 )
	 select @RegularBingo,  
	  bcd.bcdCardNo, bch.bchSessionGamesPlayedID from BingoCardDetail bcd
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
	and rdi.GameTypeID not in (4,20)
--	and bch.bchCardVoided = 0
	--and rdi.CardMediaID = 1
	and sgp.IsContinued = 0
	
   -------------------voids for regular bingo----------------------------------------
   insert into @RegularVoids
		
			select sgp.SessionGamesPlayedID, COUNT(distinct bcd.bcdCardNo)					 
					 from RegisterReceipt rr
				join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
				join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
				join BingoCardHeader bch 
					  on rdi.RegisterDetailItemID = bch.bchRegisterDetailItemID
			    join BingoCardDetail bcd on bch.bchMasterCardNo = bcd.bcdMasterCardNo
						and bch.bchSessionGamesPlayedID = bcd.bcdSessionGamesPlayedID
				join SessionGamesPlayed sgp
					  on bch.bchSessionGamesPlayedID = sgp.SessionGamesPlayedID
				join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID		
				where  
				rr.GamingDate = CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
				
				AND rr.OperatorID=@OperatorID 
				and (@Session=0 or sp.GamingSession = @Session)
				and sgp.IsContinued = 0
				and rdi.GameTypeID not in (4,20)	
				and rr.RegisterReceiptID  in 
					( select isnull(OriginalReceiptID,0) from RegisterReceipt)
			group by sgp.SessionGamesPlayedID;	
					
		update a 
		set cardCountVoid = v.cardCountVoid
		from @AllCardNumbers a
		join @RegularVoids v
		on v.sessionGamesPlayedID = a.sessionGamesPlayedID;
   
   ----------------------------------------------------------------------------------------
    
 

	insert @Results
	(
		groupName,
		noOfCards ,		
		cardStartNo ,
		cardEndNo ,
		noOfCardsVoided
		)
	select @RegularBingo, COUNT(*), MIN(cardno), MAX(cardNo),isnull(MAX( cardCountVoid),0)
    from @AllCardNumbers group by sessionGamesPlayedID ;	

	
        
    -----------------------------crystal ball(HP)-----------------------------------------------
    delete @AllCardNumbers
	insert into @AllCardNumbers(groupName ,
		cardNo ,
		sessionGamesPlayedID
		 )
	 select @CrystalBingoHP,  
	  bcd.bcdCardNo, bch.bchSessionGamesPlayedID from BingoCardDetail bcd
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
	and rdi.GameTypeID = 4
--	and bch.bchCardVoided = 0
	and bch.bchIsQuickPick = 0
	--and rdi.CardMediaID = 1
	and sgp.IsContinued = 0
	 
	 
	 
	insert @Results
	(
		groupName,
		noOfCards ,		
		cardStartNo ,
		cardEndNo ,
		noOfCardsVoided
		)
		
	select @CrystalBingoHP, count(cardNo),MIN(cardno),MAX(cardno),isnull(MAX( cardCountVoid),0) from
	  @AllCardNumbers group by sessionGamesPlayedID
    --------------------------------------------------------------------------------------------
    
    ------------------------------crystalbal(QP)-------------------------------------------------
     delete @AllCardNumbers
	insert into @AllCardNumbers(groupName ,
		cardNo ,
		sessionGamesPlayedID
		 )
	 select @CrystalBingoQP,  
	  bcd.bcdCardNo, bch.bchSessionGamesPlayedID from BingoCardDetail bcd
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
	and rdi.GameTypeID = 4
--	and bch.bchCardVoided = 0
	and bch.bchIsQuickPick = 1
	--and rdi.CardMediaID = 1
	and sgp.IsContinued = 0
	 
	 
	 
	insert @Results
	(
		groupName,
		noOfCards ,		
		cardStartNo ,
		cardEndNo ,
		noOfCardsVoided
		)
		
	select @CrystalBingoQP, count(cardNo),MIN(cardno),MAX(cardno),MAX( cardCountVoid) from
	  @AllCardNumbers group by sessionGamesPlayedID
    ---------------------------------------------------------------------------------------------  
	
	
	
    
    -----------------------------------Slingo--------------------------------------------------------
    delete @AllCardNumbers
	insert into @AllCardNumbers(groupName ,
		cardNo ,
		sessionGamesPlayedID
		 )
	 select @RegularBingo,  
	  bcd.bcdCardNo, bch.bchSessionGamesPlayedID from BingoCardDetail bcd
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
	and rdi.GameTypeID = 20
--	and bch.bchCardVoided = 0
	--and rdi.CardMediaID = 1
	and sgp.IsContinued = 0
	
	 
	 
	insert @Results
	(
		groupName,
		noOfCards ,		
		cardStartNo ,
		cardEndNo ,
		noOfCardsVoided
		)
		
	select @Slingo, count(cardNo),MIN(cardno),MAX(cardno),MAX( cardCountVoid) from
	  @AllCardNumbers group by sessionGamesPlayedID
	 
	--------------------------------------------------------------------------------------------------
				
	------------VOIDS------------------------------
		
		
		
		update @Results
		set noOfCardsVoided = 
			isnull((select sum(rdi.CardCount) as CardsVoided 					   
					 from RegisterReceipt rr
				join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
				join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
				join BingoCardHeader bch
					on rdi.RegisterDetailItemID = bch.bchRegisterDetailItemID
				join SessionGamesPlayed sgp 
					on bch.bchSessionGamesPlayedID = sgp.SessionGamesPlayedID
				join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID	
			 
				where bch.bchIsQuickPick = 0		
				and 
				rr.GamingDate = CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
				AND rr.OperatorID=@OperatorID 
				and (@Session=0 or sp.GamingSession = @Session)
				and sgp.IsContinued = 0
				and rdi.GameTypeID = 4
				and rr.RegisterReceiptID in 
					( select isnull(OriginalReceiptID,0) from RegisterReceipt)),0)
					
		where groupName = @CrystalBingoHP;
		
		update @Results
		set noOfCardsVoided = 
			isnull((select sum(rdi.CardCount) as Cardsvoided 		     
					 from RegisterReceipt rr
				join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
				join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
				join BingoCardHeader bch 
					on rdi.RegisterDetailItemID = bch.bchRegisterDetailItemID
				join SessionGamesPlayed sgp 
					on bch.bchSessionGamesPlayedID = sgp.SessionGamesPlayedID
				join SessionPlayed sp on sgp.SessionPlayedID = sp.SessionPlayedID
				
				where bch.bchIsQuickPick = 1	
				and 
				rr.GamingDate = CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)
				AND rr.OperatorID=@OperatorID 
				and (@Session=0 or sp.GamingSession = @Session)  
				and sgp.IsContinued = 0  
				and rdi.GameTypeID = 4 
				and rr.RegisterReceiptID  in 
					( select isnull(OriginalReceiptID,0) from RegisterReceipt) ),0)
					
		where groupName = @CrystalBingoQP;
		
		update @Results
		set noOfCardsVoided = 
			isnull((select SUM (rdi.CardCount) 		      
			 from RegisterReceipt rr
		join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
		join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
		join SessionPlayed sp on rd.SessionPlayedID = sp.SessionPlayedID
		join SessionGamesPlayed sgp on sp.SessionPlayedID = sgp.SessionGamesPlayedID
		
		where 
		rr.GamingDate = CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)	
		 
		AND rr.OperatorID=@OperatorID 
		and (@Session=0 or sp.GamingSession = @Session)  
		and sgp.IsContinued = 0  
		and rdi.GameTypeID = 20 	
	    and rr.RegisterReceiptID  in 
			( select isnull(OriginalReceiptID,0) from RegisterReceipt) ),0)					
		where groupName = @Slingo;
	
	select * from @Results;
end;








GO

