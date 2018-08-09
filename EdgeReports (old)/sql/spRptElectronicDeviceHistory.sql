USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicDeviceHistory]    Script Date: 04/30/2012 13:22:30 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptElectronicDeviceHistory]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptElectronicDeviceHistory]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptElectronicDeviceHistory]    Script Date: 04/30/2012 13:22:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO










CREATE PROCEDURE [dbo].[spRptElectronicDeviceHistory]
-- =============================================
-- Author:		Satish Anju
-- Description:	Electronic Device History.
--
-- SA: New report
---2012.03.15 bsb: DE100138, DE10139 game cards not counted properly
-- =============================================
@OperatorID     as INT,
@StartDate		AS DATETIME,
@EndDate		AS DATETIME,
@Session		AS INT,
@SerialNbrDevice	AS NVARCHAR(64)

AS
BEGIN

-- Validate params
if(@SerialNbrDevice is null) 
begin
    set @SerialNbrDevice = '%';
end;

--Network Devices
CREATE TABLE  #Table1
(
TransactionNumber		INT,
SerialNumber			NVARCHAR(64),
DTStamp					DATETIME,
SessionID				INT,
GammingSession			INT,
RegisterReceiptID		INT,
OriginalRegisterReceiptID		INT,
TransactionType			NVARCHAR(30),
PackNumber				INT,
NoOfCards				INT,
Price					MONEY,
ulUnlockDate            DATETIME,
ulPackLoginAssignDate   DATETIME,
SaleSuccess             BIT,
UnitNumber              INT,
SoldToMachineID         INT,
ulSoldToMachineID       INT,
ulUnitNumber            INT,
DeviceType              NVARCHAR(32),
ulID                    INT,
)
---------------------------------------------------------
 declare @AllCardNumbers table
(        
	cardNo int,
	sessionGamesPlayedID int,
	registerReceiptID int
	
)
declare @temptable table
(
    cardNo int,
	sessionGamesPlayedID int,
	registerReceiptID int

)
insert into @AllCardNumbers
select  bcd.bcdCardNo,bcd.bcdSessionGamesPlayedID, rr.RegisterReceiptID from RegisterReceipt rr
	join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
	join RegisterDetailItems rdi on rd.RegisterDetailID = rdi.RegisterDetailID
	join BingoCardHeader bch on rdi.RegisterDetailItemID = bch.bchRegisterDetailItemID
	join BingoCardDetail bcd on bch.bchMasterCardNo = bcd.bcdMasterCardNo and 
	                            bch.bchSessionGamesPlayedID = bcd.bcdSessionGamesPlayedID
	where RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
    AND RR.GamingDate <= CAST(CONVERT(varchar(12),@EndDate, 101) AS smalldatetime) 
     AND RR.OperatorID=@OperatorID   
     
 insert into @temptable
    
 select cardno,sessiongamesplayedid, registerReceiptID
  from @AllCardNumbers u1 
  where sessiongamesplayedid = (select max(sessiongamesplayedid) 
                 from @AllCardNumbers u2 
                 where u1.cardno = u2.cardno)
---------------------------------------------------------

INSERT INTO #Table1
(
TransactionNumber ,
SerialNumber,
DTStamp ,
SessionID ,
GammingSession ,
RegisterReceiptID ,
TransactionType ,
PackNumber ,
NoOfCards ,
Price,
ulUnlockDate,
ulPackLoginAssignDate,
SaleSuccess,
UnitNumber ,
SoldToMachineID ,
ulUnitNumber,
ulSoldToMachineID,
DeviceType,
ulID  
)

select   RR.TransactionNumber,
	     case when ulSoldToMachineID is null
		   then isnull(ulUnitSerialNumber,'')
		   else
		   isnull(M.SerialNumber,'') end,
         RR.DTStamp,
         SP.SessionPlayedID,
         SP.GamingSession,
         RR.RegisterReceiptID,
         TT.TransactionType,
         RR.PackNumber,
         sum(RDI.CardCount * RD.Quantity) as NoOfCards,
         sum(RDI.Price * RD.Quantity * RDI.Qty ) as Price,
         ulUnlockDate, 
         ulPackLoginAssignDate,
         RR.SaleSuccess,
         RR.Unitnumber,
         RR.SoldToMachineID,
         ulUnitNumber,
         ulSoldToMachineID,
         D.DeviceType,
         ulID
      
       
From   RegisterReceipt RR  
       LEFT JOIN RegisterDetail RD ON (RD.RegisterReceiptID = RR.RegisterReceiptID)
       LEFT JOIN RegisterDetailItems RDI ON (RDI.RegisterDetailID = RD.RegisterDetailID)
	   LEFT JOIN SessionPlayed SP ON (SP.SessionPlayedID=RD.SessionPlayedID) 
	   LEFT JOIN UnlockLog (nolock) 
		ON  (RR.RegisterReceiptID = ulregisterReceiptID and RR.GamingDate = ulGamingDate)
	   LEFT JOIN Device D (nolock) ON (ulDeviceID = D.DeviceID)
	   LEFT JOIN TransactionType TT ON (TT.TransactionTypeID = RR.TransactionTypeID)
	   LEFT JOIN Machine M  ON ((M.MachineID =  ulSoldToMachineID )or (M.MachineID=RR.SoldToMachineID))
		 

    
WHERE   RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
	    AND RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
        AND RR.OperatorID=@OperatorID
		AND RR.TransactionTypeID in (1)   
        and (RDI.CardMediaID = 1 OR RDI.CardMediaID IS NULL)
        --AND ((M.SerialNumber = @SerialNbrDevice) or (ulUnitSerialNumber = @SerialNbrDevice) or @SerialNbrDevice = 0 )
        --AND ((M.SerialNumber like @SerialNbrDevice ) and (ulUnitSerialNumber like @SerialNbrDevice))
        And (@Session = 0 or SP.GamingSession = @Session)
        AND (RR.DeviceID not in (1,2) or RR.DeviceID is null)
        AND (RR.PackNumber > 0  or RR.DeviceID > 0)
      
GROUP BY   ulID,
           RR.DeviceID,
           ulUnitSerialNumber,
		   M.SerialNumber,
		   RR.TransactionNumber,
           RR.DTStamp,
           ulSoldToMachineID,
           SP.SessionPlayedID,
           SP.GamingSession,
		   RR.RegisterReceiptID,
		   TT.TransactionType,
	       RR.PackNumber,
	       ulUnlockDate, 
           ulPackLoginAssignDate,
           SaleSuccess,
           RR.Unitnumber,
           RR.SoldToMachineID,
           ulUnitNumber,       
           D.DeviceType        
           
ORDER BY   RR.TransactionNumber	

---CRATE DEVICES

 INSERT INTO #Table1
(
TransactionNumber ,
SerialNumber,
DTStamp ,
SessionID ,
GammingSession ,
RegisterReceiptID ,
TransactionType ,
PackNumber ,
NoOfCards ,
Price,
ulUnlockDate,
ulPackLoginAssignDate,
SaleSuccess,
UnitNumber ,
SoldToMachineID ,
ulUnitNumber,
ulSoldToMachineID,
DeviceType,
ulID    
)
select   RR.TransactionNumber,
	     ISNULL(RR.UnitSerialNumber,''),
	      case when ulSoldToMachineID is null
		   then RR.DTStamp
		   else null end,
         SP.SessionPlayedID,
         SP.GamingSession,
         RR.RegisterReceiptID,
         TT.TransactionType,
         RR.PackNumber,
         sum(RDI.CardCount * RD.Quantity) as NoOfCards,
         sum(RDI.Price * RD.Quantity * RDI.Qty ) as Price,
         ulUnlockDate, 
         ulPackLoginAssignDate,
         RR.SaleSuccess,
         RR.Unitnumber,
         RR.SoldToMachineID,
         ulUnitNumber,
         ulSoldToMachineID,
         D.DeviceType,
         ulID      
       
From    RegisterReceipt RR
        LEFT JOIN RegisterDetail RD ON (RD.RegisterReceiptID = RR.RegisterReceiptID)
        LEFT JOIN RegisterDetailItems RDI ON (RDI.RegisterDetailID = RD.RegisterDetailID)
	    LEFT JOIN SessionPlayed SP ON (SP.SessionPlayedID=RD.SessionPlayedID) 
	    LEFT JOIN UnlockLog (nolock) 
		ON  (RR.RegisterReceiptID = ulregisterReceiptID and RR.GamingDate = ulGamingDate)
		LEFT JOIN Device D (nolock) ON (RR.DeviceID = D.DeviceID)
		LEFT JOIN TransactionType TT ON (TT.TransactionTypeID = RR.TransactionTypeID)
		LEFT JOIN Machine M  ON ((M.MachineID =  ulSoldToMachineID ) )

    
WHERE   RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
	    AND RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
        AND RR.OperatorID=@OperatorID
	    AND RR.TransactionTypeID in (1)    
        and(RDI.CardMediaID = 1 OR RDI.CardMediaID IS NULL)
        --AND ( RR.UnitSerialNumber = @SerialNbrDevice  or @SerialNbrDevice = 0 )
        --AND ((RR.UnitSerialNumber like @SerialNbrDevice))
        And (@Session = 0 or SP.GamingSession = @Session)
        AND (RR.DeviceID  in (1,2) )
        AND (RR.PackNumber > 0  or RR.DeviceID > 0)
     
GROUP BY   ulID,
		   RR.DeviceID,
		   ulUnitSerialNumber,
		   RR.UnitSerialNumber,
		   M.SerialNumber,
           RR.TransactionNumber,
           RR.DTStamp,
           SP.SessionPlayedID,
           SP.GamingSession,
		   RR.RegisterReceiptID,
		   TT.TransactionType,
	       RR.PackNumber,
	       ulUnlockDate, 
           ulPackLoginAssignDate,
           SaleSuccess,
           RR.Unitnumber,
           RR.SoldToMachineID,
           ulUnitNumber,
           ulSoldToMachineID,
           D.DeviceType
          
ORDER BY   RR.TransactionNumber	
create table #CardCount
(
	totalCards int,
	registerRecieptId int,
);  
declare @XVoidTransactionNumber		INT,
		@XVoidSerialNumber			NVARCHAR(64),
		@XVoidDTStamp				DATETIME,
		@XVoidSessionID				INT,
		@XVoidGammingSession		INT,
		@XVoidRegisterReceiptID		INT,
		@XVoidTransactionType		NVARCHAR(30),
		@XVoidPackNumber			INT,
		@XVoidNoOfCards				INT,
		@XVoidPrice					MONEY,
		@XFerOriginalReceiptID      INT,
		@XFerSaleSuccess            BIT,
		@XFerUnitNumber             INT,
		@XFerSoldToMachineID        INT,
		@XFerDeviceType	            NVARCHAR(32)
		
DECLARE XVoid_Cursor CURSOR FOR
SELECT RR.TransactionNumber,
	   RR.UnitSerialNumber,
       RR.DTStamp,      
       RR.RegisterReceiptID,
       TT.TransactionType,      
       RR.OriginalReceiptID,
       RR.SaleSuccess,
       RR.UnitNumber,
       RR.SoldToMachineID,
        D.Devicetype
       
       
              
From   RegisterReceipt RR   
       LEFT JOIN RegisterDetail RD ON (RD.RegisterReceiptID = RR.RegisterReceiptID)   
       LEFT JOIN RegisterDetailItems RDI ON (RDI.RegisterDetailID = RD.RegisterDetailID)	
	 --  LEFT JOIN UnlockLog (nolock) 
		--ON  (RR.RegisterReceiptID = ulregisterReceiptID and RR.GamingDate = ulGamingDate)
	   LEFT JOIN Device D (nolock) ON (RR.DeviceID = D.DeviceID)
	   LEFT JOIN TransactionType TT ON (TT.TransactionTypeID = RR.TransactionTypeID)

    
WHERE   RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime) 
	    AND RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime) 
        AND RR.OperatorID=@OperatorID
		and(RDI.CardMediaID = 1 OR RDI.CardMediaID IS NULL)
		--AND (RR.UnitSerialNumber = @SerialNbrDevice  or @SerialNbrDevice = 0 )	
		--AND ((RR.UnitSerialNumber like @SerialNbrDevice ))	 
        AND RR.TransactionTypeID in (2,14)   
      
      
OPEN XVoid_Cursor
FETCH NEXT FROM XVoid_Cursor 
INTO  @XVoidTransactionNumber,
	  @XVoidSerialNumber,
      @XVoidDTStamp,
      @XVoidRegisterReceiptID,
      @XVoidTransactionType,                               
      @XFerOriginalReceiptID,
      @XFerSaleSuccess,
      @XFerUnitNumber ,
	  @XFerSoldToMachineID,
	  @XFerDeviceType
	   
      
WHILE @@FETCH_STATUS = 0
BEGIN
declare @Done bit,
		@LoopReceiptID int

	select @Done = 0,
		@LoopReceiptID = @XFerOriginalReceiptID

	WHILE @Done = 0
	BEGIN
		select @LoopReceiptID = ISNULL (OriginalReceiptID, @LoopReceiptID)
		from RegisterReceipt (nolock)
		where RegisterReceiptID = @LoopReceiptID

		if exists (select OriginalReceiptID from registerreceipt where registerreceiptid = @LoopReceiptID and OriginalReceiptID IS NULL)
		BEGIN
			set @Done = 1
		END
	END    
insert into #CardCount
select COUNT(cardno), @XVoidRegisterReceiptID from @temptable
where registerReceiptID = @LoopReceiptID;
	
INSERT INTO #Table1
(
TransactionNumber ,
SerialNumber,
DTStamp ,
SessionID ,
GammingSession ,
RegisterReceiptID ,
OriginalRegisterReceiptID,
TransactionType ,
PackNumber ,

SaleSuccess,
UnitNumber ,
SoldToMachineID,
DeviceType  
)

SELECT   @XVoidTransactionNumber,
           case when @XVoidSerialNumber is  not null 
		 then @XVoidSerialNumber 
		 else		 
			case when ulSoldToMachineID is null
			then isnull(ulUnitSerialNumber,'')
			else isnull(M.SerialNumber,'') end
		 end, 
		     
         @XVoidDTStamp,
		 SP.SessionPlayedID,
		 SP.GamingSession,
		 @XVoidRegisterReceiptID,
		 @LoopReceiptID,
		 @XVoidTransactionType,
		 RR.PackNumber,
	
         RR.SaleSuccess,
         @XFerUnitNumber ,
		 @XFerSoldToMachineID,
        case when @XFerDeviceType is not null
		 then @XFerDeviceType 
		 else D.DeviceType end
     
From   RegisterReceipt RR    
       LEFT JOIN RegisterDetail RD ON (RD.RegisterReceiptID = RR.RegisterReceiptID)   
       LEFT JOIN RegisterDetailItems RDI ON (RDI.RegisterDetailID = RD.RegisterDetailID)
	   LEFT JOIN SessionPlayed SP ON (SP.SessionPlayedID=RD.SessionPlayedID) 	 
	   LEFT JOIN TransactionType TT ON (TT.TransactionTypeID = RR.TransactionTypeID)
	   left join UnlockLog on (ulRegisterReceiptID=RR.RegisterReceiptID  and RR.GamingDate = ulGamingDate)
	   left join Machine M on M.MachineID=ulSoldToMachineID
	   left join Device D on D.DeviceID=ulDeviceID
		
WHERE  RR.RegisterReceiptID = @LoopReceiptID 
	   AND RR.OperatorID=@OperatorID
	   and(RDI.CardMediaID = 1 OR RDI.CardMediaID IS NULL)
	   AND (@Session = 0 or SP.GamingSession = @Session)
	    --AND ((M.SerialNumber = @SerialNbrDevice) or (ulUnitSerialNumber = @SerialNbrDevice) or @SerialNbrDevice = 0 ) 
	     --AND ( (@XVoidSerialNumber like @SerialNbrDevice) or (M.SerialNumber like @SerialNbrDevice) or (ulUnitSerialNumber like @SerialNbrDevice))
	 
			
GROUP BY  SP.SessionPlayedID,
          SP.GamingSession,  
          RR.PackNumber,
          RR.SaleSuccess,
          ulSoldToMachineID,
          ulUnitSerialNumber,
          M.SerialNumber,
          D.DeviceType
           
          
 update #Table1
 set NoOfCards=T1.Cards,
     Price =T1.price
 from (select RR.RegisterReceiptID as ID,sum(RDI.CardCount * RD.Quantity)as Cards, sum(-1 * RDI.Price * RD.Quantity * RDI.Qty ) as price
      from  RegisterReceipt RR
            LEFT JOIN RegisterDetail RD ON (RD.RegisterReceiptID = @LoopReceiptID)   
            LEFT JOIN RegisterDetailItems RDI ON (RDI.RegisterDetailID = RD.RegisterDetailID)
      where 
		    (RDI.CardMediaID = 1)  
		 
			AND RR.OperatorID=@OperatorID    
            group by RR.RegisterReceiptID) T1
      --Inner join RegisterReceipt T2 on T1.RegisterReceiptID=T2.RegisterReceiptID
where #Table1.OriginalRegisterReceiptID = @LoopReceiptID   
      
       
FETCH NEXT FROM XVoid_Cursor 
INTO  @XVoidTransactionNumber,
      @XVoidSerialNumber,
      @XVoidDTStamp,
      @XVoidRegisterReceiptID,
      @XVoidTransactionType,                               
      @XFerOriginalReceiptID,
      @XFerSaleSuccess,
      @XFerUnitNumber ,       
      @XFerSoldToMachineID,
      @XFerDeviceType
	
      
END
CLOSE  XVoid_Cursor
DEALLOCATE XVoid_Cursor    
 
                            
insert into #CardCount
select COUNT(cardno), registerreceiptID from @temptable
group by registerReceiptID
 
   
Update #Table1
set #Table1.Price = (#Table1.Price - ISNULL ((Select SUM (rd.Quantity * rdi.QTY * rdi.Price)
									from RegisterDetailItems rdi (nolock)
									left join RegisterDetail rd (nolock) on rdi.RegisterDetailID = rd.RegisterDetailID
									left join RegisterReceipt rr (nolock) on rd.RegisterReceiptID = rr.RegisterReceiptID
									where rr.TransactionNumber = #Table1.TransactionNumber and 
									(rdi.CardMediaID IS NULL)
									GROUP BY rr.TransactionNumber), 0))
     
update #Table1
set NoOfCards = (select totalCards from #CardCount
                 where #Table1.RegisterReceiptID = #CardCount.registerRecieptId);
                  


SELECT * FROM #Table1 
         WHERE SerialNumber like @SerialNbrDevice 
         ORDER BY ulID

DROP TABLE #Table1
DROP TABLE #CardCount
END 











GO


