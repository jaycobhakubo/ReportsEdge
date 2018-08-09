USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperTransactionDetail]    Script Date: 05/21/2012 10:04:31 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO








ALTER PROCEDURE [dbo].[spRptPaperTransactionDetail] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@Session	as int,
	@StaffID	as int	
AS
SET NOCOUNT ON

SET @EndDate = DateAdd(day, 1, @EndDate)


--05/18/2012 DE10399|knc : fixed (Date issue)
--120711 BSB: DE9724-Added transacation type 32 for paper transfer

-----------------
--TEST
--declare
--	@OperatorID	as int,
--	@StartDate	as SmallDatetime,
--	@EndDate	as SmallDateTime,
--	@Session	as int,
--	@StaffID	as int	

--set @OperatorID = 1
--set @StartDate = '5/15/2012 00:00:00'
--set @EndDate = '5/15/2012 00:00:00'
--set @StaffID = 0
--set @Session = 0
------------------------



declare @TmpIndex int,
		@TransType int,
		@TransDtlId int

CREATE TABLE #TempTble
	(
		txID int,
		txMID int,
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
		txStart int,
		txEnd int,
		txQty int,
		txPrice money,
		txValue money
	)
	
INSERT INTO #TempTble
	(txID,
	txMID,
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
	 txStart, 
	 txEnd, 
	 txQty, 
	 txPrice, 
	 txValue)
	SELECT invT.ivtInvTransactionID,
	invt.ivtMasterTransactionID ,
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
	WHERE 
	(o.OperatorID = @OperatorID or @OperatorID = 0) AND							-- DE7585
	invT.ivtTransactionTypeID IN (3,23,25,27, 32)
	--AND invT.ivtInvTransactionDate >= CAST(CONVERT(varchar(12), @StartDate, 101) AS SMALLDATETIME)
	--AND invT.ivtInvTransactionDate <= CAST(CONVERT(varchar(12), @EndDate, 101) AS SMALLDATETIME)
	AND (@Session = 0 OR @Session = invT.ivtGamingSession)
	AND prod.ProductTypeID = 16;         -- DE7241 - Only include paper products.


	
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
							   --ORDER BY itd.ivdDelta ASC --removed 5/21/2012 00:00:00
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
	
	select 
	a.txID ,
		a.txMID ,
		txTimestamp ,
		txSession ,
		txStaff ,
		txStaffName ,       -- DE7724
		txProductID ,
		txProductName ,
		txSerialNo ,
		txTransTypeID ,
		txTransTypeName ,
		txStaff2 ,
		txStaff2FirstName ,
		txStaff2LastName ,
		txStart ,
		txEnd ,
		txQty ,
		txPrice ,
		txValue 
	 from #TempTble  a join
(	
SELECT txID FROM #TempTble
where 
	 txTimestamp >= CAST(CONVERT(varchar(14), @StartDate, 101) AS SMALLDATETIME)
	AND txTimestamp <= CAST(CONVERT(varchar(14), @EndDate, 101) AS SMALLDATETIME)) b
	on a.txMID = b.txID 
	where a.txMID is not null
	union all 
		select 
	txID ,
		txMID ,
		txTimestamp ,
		txSession ,
		txStaff ,
		txStaffName ,       -- DE7724
		txProductID ,
		txProductName ,
		txSerialNo ,
		txTransTypeID ,
		txTransTypeName ,
		txStaff2 ,
		txStaff2FirstName ,
		txStaff2LastName ,
		txStart ,
		txEnd ,
		txQty ,
		txPrice ,
		txValue 
	 from #TempTble 
	 where 
	 txTimestamp >= CAST(CONVERT(varchar(14), @StartDate, 101) AS SMALLDATETIME)
	AND txTimestamp <= CAST(CONVERT(varchar(14), @EndDate, 101) AS SMALLDATETIME)
		and txMID is null
	

	
DROP TABLE #TempTble;

SET NOCOUNT OFF;








GO


