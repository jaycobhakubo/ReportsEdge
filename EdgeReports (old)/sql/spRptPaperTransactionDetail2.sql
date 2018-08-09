USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperTransactionDetail2]    Script Date: 05/23/2012 15:59:29 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPaperTransactionDetail2]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPaperTransactionDetail2]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperTransactionDetail2]    Script Date: 05/23/2012 15:59:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
























CREATE PROCEDURE [dbo].[spRptPaperTransactionDetail2] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@Session	as int,
	@StaffID	as int	
AS
SET NOCOUNT ON
------------------------------
--DE10401|5/17/2012|knc: Fixed date transfer issue


-----------------------------
	--test
--declare 
--@OperatorID		int = 1,
--@StartDate		datetime = '5/15/2012 00:00:00',
--@EndDate		datetime = '5/15/2012 00:00:00',
--@Session		int = 0, 
--@StaffID		int = 0
--	SET @EndDate = DateAdd(day, 1, @EndDate) ??

declare @TmpIndex int,
		@TransType int,
		@TransDtlId int

CREATE TABLE #TempTble
	(
		txID int,
		MasterTrans int,
		txTimestamp SmallDateTime,
		txSession int,
		txStaff int,
		txStaffName nvarchar(64),       -- DE7724
		txProductID int,
		txProductName nvarchar(260),
		txSerialNo nvarchar(260),
		txTransTypeID int,
		txTransTypeName nvarchar(260),
		txStaff2 int,
		txStaff2FirstName nvarchar(260),
		txStaff2LastName nvarchar(260),
		--txStaffFirstTo nvarchar(260),
		--txStaffLastto nvarchar(260),
		--txIssuedTo varchar(260),
		txStart int,
		txEnd int,
		txQty int,
		txPrice money,
		txValue money
	)
	
	INSERT INTO #TempTble
	(txID,
	MasterTrans, 
	 txTimestamp, 
	 txSession, 
	 txStaff, 
	 txStaffName,   -- DE7724
	 txProductID, 
	 txProductName, 
	 txSerialNo, 
	 txTransTypeID, 
	 txTransTypeName, 
	 txStaff2, 
	 txStaff2FirstName,
	 txStaff2LastName,
		--txIssuedTo,
	 txStart, 
	 txEnd, 
	 txQty, 
	 txPrice, 
	 txValue)

SELECT invT.ivtInvTransactionID,
isnull(invt.ivtMasterTransactionID ,invT.ivtInvTransactionID),
		   invT.ivtInvTransactionDate, 
		   invT.ivtGamingSession,
		   invT.ivtStaffID,
		   s.LastName + ', ' + s.FirstName,     -- DE7724
		   invI.iiProductItemID,
		   prod.ItemName,
		   invI.iiSerialNo,
		   invT.ivtTransactionTypeID,
		   transT.TransactionType,
		   0,
		   '',
		   '',
		 -- 	  st.FirstName +' '+st.LastName , 
		   invT.ivtStartNumber,
		   invT.ivtEndNumber,
		   0,
		   invT.ivtPrice,
		   0
		   
	--FROM InvTransaction invT
	FROM Operator o																-- DE7585
	join ProductItem pi on pi.OperatorID = o.OperatorID							-- DE7585
	join InventoryItem i on i.iiProductItemID = pi.ProductItemID				-- DE7585
	join InvTransaction invT on invT.ivtInventoryItemID = i.iiInventoryItemID	-- DE7585
	
	JOIN InventoryItem invI ON (invT.ivtInventoryItemID = invI.iiInventoryItemID)
	JOIN ProductItem prod ON (invI.iiProductItemID = prod.ProductItemID)
	JOIN TransactionType transT ON (transT.TransactionTypeID = invT.ivtTransactionTypeID)
	
	join Staff s on invT.ivtStaffID = s.StaffID     -- DE7724
	--left join InvTransactionDetail ivd on ivd.ivdInvTransactionID = invt.ivtInvTransactionID 
	--left join InvLocations invl on invl.ilInvLocationID = ivd.ivdInvLocationID 
	--left join Staff st on st.StaffID = invl.ilStaffID  
	
	--36
	WHERE 
	(o.OperatorID = @OperatorID or @OperatorID = 0) AND							-- DE7585
	invT.ivtTransactionTypeID IN (3,23,25,27, 32)
	--AND invT.ivtInvTransactionDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS SMALLDATETIME)
	--AND invT.ivtInvTransactionDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS SMALLDATETIME)
	AND (@Session = 0 OR @Session = invT.ivtGamingSession)
	AND prod.ProductTypeID = 16;         -- DE7241 - Only include paper products.       -- DE7241 - Only include paper products.

	-- Next, Update the Quantity from the detail record for the row specified
	DECLARE TempTableCursor CURSOR FOR
	SELECT txID FROM #TempTble;
	
	OPEN TempTableCursor;
	
	FETCH NEXT FROM TempTableCursor INTO @TmpIndex;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		
		SET @TransType = (SELECT ivtTransactionTypeID 
						  FROM InvTransaction 
						  WHERE ivtInvTransactionID = @TmpIndex);
	
		-- Return
		IF @TransType IN (3, 23, 27,32)
		BEGIN
			-- Return should look for lowest delta
			SET @TransDtlId = (SELECT TOP 1 ivdInvTransactionDetailID
							   FROM InvTransactionDetail itd
							   JOIN InvTransaction it ON (itd.ivdInvTransactionID = it.ivtInvTransactionID)
							   WHERE it.ivtInvTransactionID = @TmpIndex
							   --ORDER BY itd.ivdDelta ASC
							   );							   
			
			-- Set the staff that returned the data				   
			UPDATE #TempTble
			SET txStaff2 = (SELECT TOP 1 ilStaffID
							FROM InvLocations il
							JOIN InvTransactionDetail itd ON (il.ilInvLocationID = itd.ivdInvLocationID)
							WHERE itd.ivdInvTransactionDetailID = @TransDtlId
							ORDER BY itd.ivdDelta ASC)
			WHERE txID = @TmpIndex; 				
			
			-- Set the quantity into the table
			UPDATE #TempTble
			SET txQty = (SELECT ivdDelta
						 FROM InvTransactionDetail
						 WHERE ivdInvTransactionDetailID = @TransDtlId)
			WHERE txID = @TmpIndex;
		END
		ELSE
		BEGIN
			-- Issue should look for highest delta
			SET @TransDtlId = (SELECT TOP 1 ivdInvTransactionDetailID
							   FROM InvTransactionDetail itd
							   JOIN InvTransaction it ON (itd.ivdInvTransactionID = it.ivtInvTransactionID)
							   WHERE it.ivtInvTransactionID = @TmpIndex
							   ORDER BY itd.ivdDelta DESC);							   
			
			-- Set the staff that returned the data				   
			UPDATE #TempTble
			SET txStaff2 = (SELECT TOP 1 ilStaffID
							FROM InvLocations il
							JOIN InvTransactionDetail itd ON (il.ilInvLocationID = itd.ivdInvLocationID)
							WHERE itd.ivdInvTransactionDetailID = @TransDtlId
							ORDER BY itd.ivdDelta ASC)
			WHERE txID = @TmpIndex; 				
			
			-- Set the quantity into the table
			UPDATE #TempTble
			SET txQty = (SELECT ivdDelta
						 FROM InvTransactionDetail
						 WHERE ivdInvTransactionDetailID = @TransDtlId)
			WHERE txID = @TmpIndex;
		END
		
		FETCH NEXT FROM TempTableCursor INTO @TmpIndex;
	END
	
	CLOSE TempTableCursor;
	DEALLOCATE TempTableCursor;

	Update #TempTble
	SET txValue = txQty * txPrice;

	Update #TempTble
	SET txStaff2FirstName = s.FirstName,
		txStaff2LastName = s.LastName
	FROM #TempTble tt
	JOIN Staff s on (tt.txStaff2 = s.StaffID);
	
	IF @StaffID <> 0
	BEGIN
		DELETE FROM #TempTble
		WHERE txStaff2 <> @StaffID;
	END

--select * from #TempTble 

	dECLARE @A TABLE 
(
		txID int,
		MasterTrans int,
		txTimestamp SmallDateTime,
		txSession int,
		txStaff int,
		txStaffName nvarchar(64),     
		txProductID int,
		txProductName nvarchar(260),
		txSerialNo nvarchar(260),
		txTransTypeID int,
		txTransTypeName nvarchar(260),
		txStaff2 int,
		txStaff2FirstName nvarchar(260),
		txStaff2LastName nvarchar(260),
		txStart int,
		txEnd int,
		txQty int,
		txPrice money,
		txValue money)
		
INSERT INTO @A
SELECT txID,
	isnull(MasterTrans, txID), 
	 txTimestamp, 
	 txSession, 
	 txStaff, 
	 txStaffName,   
	 txProductID, 
	 txProductName, 
	 txSerialNo, 
	 txTransTypeID, 
	 txTransTypeName, 
	 txStaff2, 
	 txStaff2FirstName,
	 txStaff2LastName,
	 txStart, 
	 txEnd, 
	 txQty, 
	 txPrice, 
	 txValue
	 FROM #TempTble WHERE txTransTypeID in (25)
	 
--select * from @A 
	 
	dECLARE @B TABLE 
(
		txID int,
		MasterTrans int,
		txTimestamp SmallDateTime,
		txSession int,
		txStaff int,
		txStaffName nvarchar(64),      
		txProductID int,
		txProductName nvarchar(260),
		txSerialNo nvarchar(260),
		txTransTypeID int,
		txTransTypeName nvarchar(260),
		txStaff2 int,
		txStaff2FirstName nvarchar(260),
		txStaff2LastName nvarchar(260),
		txStart int,
		txEnd int,
		txQty int,
		txPrice money,
		txValue money)
		
INSERT INTO @B
SELECT txID,
	isnull(MasterTrans, txID), 
	 txTimestamp, 
	 txSession, 
	 txStaff, 
	 txStaffName,
	 txProductID, 
	 txProductName, 
	 txSerialNo, 
	 txTransTypeID, 
	 txTransTypeName, 
	 txStaff2, 
	 txStaff2FirstName,
	 txStaff2LastName,
	 txStart, 
	 txEnd, 
	 txQty, 
	 txPrice, 
	 txValue
	 FROM #TempTble WHERE txTransTypeID in (3,32)

 

declare @c table
(	ID int,
MasterID int,
		[Date] SmallDateTime,
		[Session] int,
		IssuedBy varchar(250),

		ProductID int,
		ProductName nvarchar(260),
		SerialNo nvarchar(260),
		TransTypeID int,
		TransTypeName nvarchar(260),
		IssuedTo varchar(250),
		Start int,
		[End] int,
		Qty int,
		Returned int,
		Price money)
		--Value money)
insert into @c
select a.txID,
a.MasterTrans,
	 a.txTimestamp, 
	 a.txSession, 
	 a.txStaffName+' ('+CAST(a.txStaff as varchar(10))+')' ,   
	 	 a.txProductID, 
	 a.txProductName, 
	 a.txSerialNo, 
	 a.txTransTypeID, 
	 a.txTransTypeName, 
	 a.txStaff2LastName+', '+a.txStaff2FirstName+' ('+cast(a.txStaff2 as varchar(50))+')',
	 a.txStart, 
	 a.txEnd, 
	 a.txQty as issued ,
	 (ISNULL(B.txQty,0 )+ ISNULL(c.TXQTY , 0)) as [returned],
	 a.txPrice 
--(a.txQty + (ISNULL(B.txQty,0 )+ ISNULL(c.TXQTY , 0))) * a.txPrice  as txValue
	 	from @a a left join @B B ON A.txID = B.MasterTrans  
	 AND A.txSession = B.txSession 
	 LEFT JOIN @B C ON A.txID <> C.MasterTrans  AND A.MasterTrans = C.MasterTrans 
AND A.txSession = c.txSession 

----------------------------------------------------------------------------------	 	



select 
 ID2 = ROW_NUMBER() OVER ( ORDER BY MasterID) ,
 ID = ROW_NUMBER() OVER (PARTITION BY MasterID  ORDER BY MasterID)  ,
MasterID ,

[Date] ,
[Session] ,
IssuedBy ,
ProductID ,
ProductName,
SerialNo ,
TransTypeID ,
TransTypeName ,
IssuedTo ,
case 
when Start = 0 then '-'
else
CAST(start as varchar(13)) end as [Start],
[End] ,
Qty ,
case
when Start <> 0 and [End] <> 0 then '-' 
when Start = 0 and [End] = 0 then cast(Qty as varchar(13)) 
End as Issued,
Returned,

Price 
--Value
into #a
 from @c 



 select 
 (select SUM(b.Returned) from #a b
 where b.ID2 <= a.ID2
 and b.MasterID = a.MasterID ) as x,

 * into #b from #a   a
 

 
 select 
 a.*,

 case 
 when a.Issued = 0 then cast(a.[End] + a.x AS varchar(13))
 when a.Issued > 0 then '-'
 end as End2,
 case 
when Start <> 0 and [End] <> 0 then ([End] - Start + 1) + x
when Start = 0 and [End] = 0 then Qty + x End as Qty2 
into #c 
 from #b a
 where cast(CONVERT(VARCHAR(10),a.[Date],10) as smalldatetime) >= cast(CONVERT(VARCHAR(10),@StartDate ,10) as smalldatetime)
 and cast(CONVERT(VARCHAR(10),a.[Date],10) as smalldatetime) <= cast(CONVERT(VARCHAR(10),@EndDate ,10) as smalldatetime)


 select *, Qty2 * Price as Value into #d from #c 
 
 select /***/
 MasterID , [Date], [Session], ProductName , 
 case when len(SerialNo) > 1 then SerialNo 
 else null end [SerialNo],
 IssuedTo, cast (
 (case when start not like '-' then start
 else null end) as int) [Start],
CAST ((case when Issued not like '-' then Issued 
else null end) as int ) [Issued] ,Returned , Price , 
CAST ((case when [End2] not like '-' then [End2]
else null end) As int) [End2],Qty2 , Value   
 --case 
 -- when 
 --b.value2 is null then 0.00
 --else b.value2 end as value2

  from #d a
 join (
 select ID2, Value as Value2 from #d a 
inner join (select MasterID, max(ID) as ID3 from #d group by MasterID) b 
 on b. MasterID = a.MasterID 
 and b.ID3 = a.ID
  ) b on b.ID2 = a.ID2
 
 
DROP TABLE #TempTble
drop table #a 
drop table #b 
drop table #c 
drop table #d 


















GO


