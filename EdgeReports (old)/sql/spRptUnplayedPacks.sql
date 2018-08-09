USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[sprptUnplayedPacks]    Script Date: 06/25/2012 16:22:02 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sprptUnplayedPacks]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[sprptUnplayedPacks]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[sprptUnplayedPacks]    Script Date: 06/25/2012 16:22:02 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





-- =============================================
CREATE PROCEDURE [dbo].[sprptUnplayedPacks]
	@OperatorID as int,
	@StartDate as smalldatetime,
	@EndDate as smalldatetime,
	@Session as int
/*
    11/30/2011 DE9582: Show the sale amount even if the pack is voided
    11/30/2011 DE9711: Ensure that the void amount is only counted once.
    11/30/2011 DE9710: Retrieve the Client ID or Serial number for network devices
    12/02/2011 DE9711: Ensure that RF sales amounts are not doubled when trnasfering a unit then voiding it.
    12/06/2011 DE9582: Added Transaction date to the result set
    12/09/2011 DE9786: Added support for Sale amount included discounts and sales tax
    12/13/2011 DE9782: Remove the non-electronic only sales from the report
    12/15/2011 DE9814: When a RF unit is transferred, return the destination unit and serial numbers.
    01/17/2012 DE9947: When device fees are charged they are not being returned properly
    05/14/2012 DE9788: Serial# on voied pack not showing up. - KC
    2012.06.01 DE9788: Added support for displaying the proper unit numbers for sales, voids, and transfers
    2012.06.25 DE9788: Fixed issue with the number of units that a pack was loaded into would adjust the
                        the calculation of the voided amount.
*/
AS
BEGIN
	SET NOCOUNT ON;
Create table #TempPacks  
 (  
  TransactionNumber int,  
  VoidTransNumber int,  
  Quantity int,  
  DiscountAmount money,  
  UnitNumber int,  
  PackNumber int,  
  DeviceType nvarchar(32),  
  VoidedRegisterReceiptID int,  
  PackagePrice money,  
  FirstName nvarchar(32),  
  LastName nvarchar(32),  
  PFirstName nvarchar(32),  
  PLastName nvarchar(32),  
  SaleSuccess bit,  
  OperatorID smallint,  
  GamingSession smallint,  
  GamingDate smalldatetime,  
  SoldToMachineID int,  
  ulSoldToMachineID int,  
  ulUnitNumber int,  
  ulPlayerID int,  
  ulID int,  
  ulGamingDate smalldatetime,  
  ulUnitSerialNumber nvarchar(30),  
  ulUnlockDate datetime,  
  ulPackLoginAssignDate datetime,  
  TransactiontypeID int,  
  TransferTransNumber int,  
  TransferSession int,  
  TransferPackNo int,  
        TransactionDate datetime  
 )  
  
-- Original Sale    
-- Network devices  
insert into #TempPacks  
 (TransactionNumber, PackagePrice, DiscountAmount, UnitNumber, PackNumber, DeviceType, VoidedRegisterReceiptID,  
  FirstName, LastName, PFirstName, PLastName, SaleSuccess,OperatorID, GamingSession, GamingDate,   
  SoldToMachineID, TransactiontypeID, ulID,ulSoldToMachineID, ulUnitNumber,  
        ulPlayerID, ulGamingDate, ulUnitSerialNumber, ulUnlockDate, ulPackLoginAssignDate, -- added the assign date  
        TransactionDate) -- Added the actual date of the transaction  
   
 SELECT RR.TransactionNumber  
        ,(isnull(sum(Quantity * PackagePrice), 0) +  
          isnull(sum(Quantity * DiscountAmount), 0) +  
          isnull(sum(SalesTaxAmt), 0) +  
          isnull(RR.DeviceFee, 0)/*DE9947*/) --DE9786  
        ,isnull (Sum(Quantity * DiscountAmount), 0), RR.UnitNumber, RR.PackNumber,  
  DeviceType, VoidedRegisterReceiptID,  
  S.FirstName, S.LastName, P.FirstName, P.LastName, RR.SaleSuccess,RR.OperatorID,   
  GamingSession, RR.GamingDate, RR.SoldToMachineID, RR.TransactiontypeID,  
  ulID, ulSoldToMachineID, ulUnitNumber, ulPlayerID, ulGamingDate  
  , (case when m.SerialNumber is null then m.ClientIdentifier else m.SerialNumber end)/*ulUnitSerialNumber*/  
  , ulUnlockDate, ulPackLoginAssignDate, RR.DTStamp -- Added the actual date of the transaction  
 FROM  RegisterReceipt RR (nolock)  
Left JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID   
Left JOIN UnlockLog (nolock)   
  on  (RR.RegisterReceiptID = ulregisterReceiptID and RR.GamingDate = ulGamingDate)  
JOIN Staff S (nolock) ON RR.StaffID = S.StaffID   
left Join Player P (nolock) on ulPlayerID = P.PlayerID  
left JOIN Device D (nolock) ON (ulDeviceID = D.DeviceID)  
left join Machine m (nolock) on ulSoldToMachineID = m.MachineID  
left Join (select distinct SessionPlayedID, GamingSession --Use derived table to  
   from History.dbo.SessionPlayed (nolock)  --eliminate UK duplicates  
   ) as SP   
   on RD.SessionPlayedID = SP.SessionPlayedID  
 WHERE RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)   
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)   
and RR.OperatorID = @OperatorID  
and (@Session = 0 or SP.GamingSession = @Session)   
and (RR.PackNumber > 0 or RR.DeviceID > 0)  
and RR.TransactiontypeID = 1  
and (RR.DeviceID not in (1, 2) or RR.DeviceID IS NULL)  
Group By RR.TransactionNumber,RR.UnitNumber, RR.PackNumber, DeviceType, VoidedRegisterReceiptID,  
  S.FirstName, S.LastName, P.FirstName, P.LastName, RR.SaleSuccess,RR.OperatorID,   
  GamingSession, RR.GamingDate, RR.SoldToMachineID, RR.TransactiontypeID,  
  ulID, ulSoldToMachineID, ulUnitNumber, ulPlayerID, ulGamingDate,   
        m.SerialNumber, m.ClientIdentifier, ulUnlockDate, ulPackLoginAssignDate,  
        RR.DTStamp, devicefee  
        
   --Crate Devices  
insert into #TempPacks  
 (TransactionNumber, PackagePrice, DiscountAmount, UnitNumber, PackNumber, DeviceType, VoidedRegisterReceiptID,  
  FirstName, LastName, PFirstName, PLastName, SaleSuccess,OperatorID, GamingSession, GamingDate,   
  SoldToMachineID, TransactiontypeID, ulID,ulSoldToMachineID, ulUnitNumber, ulPlayerID, ulGamingDate,  
        ulUnitSerialNumber, ulUnlockDate, ulPackLoginAssignDate, TransactionDate)-- added the assign date and added the date of the original transaction  
   
 SELECT RR.TransactionNumber  
        ,(isnull(sum(Quantity * PackagePrice), 0) +  
          isnull(sum(Quantity * DiscountAmount), 0) +  
          isnull(sum(SalesTaxAmt),0) +  
          isnull (DeviceFee, 0)/*DE9947*/) --DE9786  
        ,isnull (Sum(Quantity * DiscountAmount), 0), RR.UnitNumber, ulPackNumber,  
  DeviceType, VoidedRegisterReceiptID, S.FirstName, S.LastName, P.FirstName, P.LastName, RR.SaleSuccess,RR.OperatorID,   
  GamingSession, RR.GamingDate, RR.SoldToMachineID, RR.TransactiontypeID, ulID, ulSoldToMachineID, rr.UnitNumber,  
        ulPlayerID, ulGamingDate, rr.UnitSerialNumber, ulUnlockDate, rr.DTStamp,  
        rr.DTStamp -- Added the date of the original transaction  
 FROM  RegisterReceipt RR (nolock)  
-- 12/02/2011 DE9711 Left Join RegisterReceipt RR1 (nolock) on RR1.OriginalReceiptID = RR.RegisterReceiptID  
Left JOIN RegisterDetail RD (nolock) ON RR.RegisterReceiptID = RD.RegisterReceiptID   
Left JOIN UnlockLog (nolock)   
  on  (RR.RegisterReceiptID = ulregisterReceiptID and RR.GamingDate = ulGamingDate)  
JOIN Staff S (nolock) ON RR.StaffID = S.StaffID   
left Join Player P (nolock) on ulPlayerID = P.PlayerID  
left JOIN Device D (nolock) ON (RR.DeviceID = D.DeviceID)  
left Join (select distinct SessionPlayedID, GamingSession --Use derived table to  
   from History.dbo.SessionPlayed (nolock)  --eliminate UK duplicates  
   ) as SP   
   on RD.SessionPlayedID = SP.SessionPlayedID  
 WHERE RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)   
and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
and RR.OperatorID = @OperatorID  
and (@Session = 0 or SP.GamingSession = @Session)   
and (RR.PackNumber > 0 or RR.DeviceID > 0)  
and RR.TransactiontypeID = 1  
and RR.DeviceID in (1, 2)  
Group By RR.TransactionNumber,RR.UnitNumber, ulPackNumber, DeviceType, VoidedRegisterReceiptID,  
  S.FirstName, S.LastName, P.FirstName, P.LastName, RR.SaleSuccess,RR.OperatorID,   
  GamingSession, RR.GamingDate, RR.SoldToMachineID, RR.TransactiontypeID,  
  ulID, ulSoldToMachineID, rr.UnitNumber, ulPlayerID, ulGamingDate, rr.UnitSerialNumber,  
        ulUnlockDate, rr.DTStamp, devicefee  
        
  declare @XFerTransactionNumber int,  
 @XFerUnitNumber nvarchar(32),  
 @XFerUnitSerialNumber nvarchar(32),  
 @XFerPackNumber int,  
 @XFerDeviceType nvarchar(32),  
 @XFerFirstName nvarchar(32),  
 @XFerLastName nvarchar(32),  
 @XFerPFirstName nvarchar(32),  
 @XFerPLastName nvarchar(32),  
 @XFerSaleSuccess bit,  
 @XFerOperatorID int,  
 @XFerGamingSession int,  
 @XFerGamingDate datetime,  
 @XFerSoldToMachineID int,  
 @XFerTransactionTypeID int,  
 @XFerTransferTransNumber int,  
 @XFerTransferSession int,  
 @XFerOriginalReceiptID int,  
    @XFerPackLoginAssignDate datetime  
  
Declare XFer_Cursor CURSOR FOR  
SELECT RR.TransactionNumber,  RR.UnitNumber, RR.UnitSerialNumber, D.DeviceType, S.FirstName, S.LastName, RR.SaleSuccess, RR.OperatorID,   
  RR.GamingDate, RR.SoldToMachineID, RR.TransactiontypeID, RR.TransactionNumber, RR.OriginalReceiptID, RR.DTStamp  
FROM  RegisterReceipt RR (nolock)  
LEFT JOIN RegisterDetail RD ON (RD.RegisterReceiptID = RR.RegisterReceiptID)  
 JOIN Staff S (nolock) ON RR.StaffID = S.StaffID   
 left JOIN Device D (nolock) ON (RR.DeviceID = D.DeviceID)  
WHERE RR.GamingDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS smalldatetime)   
 and RR.GamingDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS smalldatetime)    
 and RR.OperatorID = @OperatorID  
 and RR.transactionTypeID in (14,2)  
  
OPEN XFer_Cursor  
FETCH NEXT FROM XFer_Cursor INTO @XFerTransactionNumber, @XFerUnitNumber, @XFerUnitSerialNumber, @XFerDeviceType, @XFerFirstName, @XFerLastName,  
 @XFerSaleSuccess, @XFerOperatorID, @XFerGamingDate, @XFerSoldToMachineID, @XFerTransactionTypeID, @XFerTransferTransNumber,  
 @XFerOriginalReceiptID, @XFerPackLoginAssignDate  
WHILE @@FETCH_STATUS = 0  
BEGIN  
    declare @Done bit
           ,@LoopReceiptID int  

    select @Done = 0
          ,@LoopReceiptID = @XFerOriginalReceiptID  
  
    while @Done = 0  
    begin  
        select @LoopReceiptID = isnull (OriginalReceiptID, @LoopReceiptID)  
        from RegisterReceipt
        where RegisterReceiptID = @LoopReceiptID  
      
        if exists (select OriginalReceiptID from registerreceipt where registerreceiptid = @LoopReceiptID and OriginalReceiptID IS NULL)  
        begin  
            set @Done = 1  
        end  
    end  
      
    insert into #TempPacks
        (TransactionNumber,PackagePrice,UnitNumber,PackNumber,DeviceType
        ,FirstName,LastName,PFirstName,PLastName,SaleSuccess,OperatorID
        ,GamingSession,GamingDate,SoldToMachineID,TransactiontypeID,TransferTransNumber
        ,TransferSession,ulUnitNumber,ulUnitSerialNumber,ulPackLoginAssignDate,TransactionDate)
    select
        @XFerTransactionNumber
        ,(case when @XFerTransactionTypeID = 2  
          then ((isnull(sum(Quantity * PackagePrice), 0) +  
                isnull(sum(Quantity * DiscountAmount), 0) +  
                isnull(sum (SalesTaxAmt), 0) +  
                isnull(devicefee, 0)/*DE9947*/) * -1)  
          --then ((isnull(sum(rd.Quantity * rd.PackagePrice), 0) +  
          --      isnull(sum(rd.Quantity * rd.DiscountAmount), 0) +  
          --      isnull(sum(SalesTaxAmt), 0) +  
          --      isnull(devicefee, 0)/*DE9947*/) * -1)  
          else 0 -- Transfers are a 0 dollar transaction  
          end)
        ,@XFerUnitNumber,rr.PackNumber,@XFerDeviceType,@XFerFirstName,@XFerLastName
        ,p.FirstName,p.LastName,@XFerSaleSuccess,@XFerOperatorID,sp.GamingSession
        ,@XFerGamingDate,@XFerSoldToMachineID,@XFerTransactionTypeID,@XFerTransferTransNumber
        ,sp.GamingSession
        ,case when @XFerTransactionTypeId = 2 and ul.ulUnitNumber <> 0 then ul.ulUnitNumber
               when @XFerTransactionTypeId = 2 and ul.ulUnitNumber = 0 then ul.ulSoldToMachineId
          else @XFerUnitNumber end
        ,case when @XFerTransactionTypeId = 2 and len(ul.ulUnitSerialNumber) <> 0 then ul.ulUnitSerialNumber
               when @XFerTransactionTypeId = 2 and len(ul.ulUnitSerialNumber) = 0 then m.SerialNumber
            else @XFerUnitSerialNumber end
        ,@XFerPackLoginAssignDate,rr.DTStamp
    from
        RegisterReceipt rr
        left join RegisterDetail rd on rr.RegisterReceiptID = rd.RegisterReceiptID
        left join UnlockLog ul on rr.RegisterReceiptId = ul.ulRegisterReceiptId
        left join Machine m on ul.ulSoldToMachineId = m.MachineId
        left join Player p on rr.PlayerID = p.PlayerID  
        left join (select distinct SessionPlayedID, GamingSession --Use derived table to  
                   from History.dbo.SessionPlayed (nolock)  --eliminate UK duplicates  
                   ) as sp on rd.SessionPlayedID = sp.SessionPlayedID  
    where rr.RegisterReceiptID = @LoopReceiptID 
        and (@Session = 0 or sp.GamingSession = @Session)
        and rd.SessionPlayedId is not null --DE9782  
        and rr.PackNumber <> 0 --DE9782 
        and ul.ulId = (select max(ulId) from UnlockLog where ulPackNumber = rr.PackNumber)
    group by  
        rr.PackNumber,p.FirstName,p.LastName,sp.GamingSession,rr.DTStamp,rr.DeviceFee
        ,ul.ulUnitNumber,ul.ulUnitSerialNumber,ul.ulSoldToMachineId,m.SerialNumber--,rd.Quantity, rd.PackagePrice
        --,rd.DiscountAmount,SalesTaxAmt
        
        
    fetch next from xfer_cursor
        into @XFerTransactionNumber, @XFerUnitNumber, @XFerUnitSerialNumber, @XFerDeviceType, @XFerFirstName
            ,@XFerLastName, @XFerSaleSuccess, @XFerOperatorID, @XFerGamingDate, @XFerSoldToMachineID
            ,@XFerTransactionTypeID, @XFerTransferTransNumber, @XFerOriginalReceiptID, @XFerPackLoginAssignDate
end
close xfer_cursor
deallocate xfer_cursor
select * from #TempPacks order by TransactionNumber asc

drop table #TempPacks   
  
set nocount off;
END







GO

