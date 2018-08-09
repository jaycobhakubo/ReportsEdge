USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperTransactionDetail]    Script Date: 10/07/2013 17:50:37 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptPaperTransactionDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptPaperTransactionDetail]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptPaperTransactionDetail]    Script Date: 10/07/2013 17:50:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[spRptPaperTransactionDetail] 
	@OperatorID	as int,
	@StartDate	as SmallDatetime,
	@EndDate	as SmallDateTime,
	@Session	as int,
	@StaffID	as int	
AS
	set nocount on;

	-- setup start and end dates.
    set @StartDate = dateadd(day, 0, datediff(day, 0, @StartDate));
    set @EndDate = dateadd(day, 1, datediff(day, 0, @EndDate));


	--05/18/2012 DE10399|knc : fixed (Date issue)
	--120711 BSB: DE9724-Added transacation type 32 for paper transfer

	declare @TmpIndex int,
		@TransType int,
		@TransDtlId int

	declare @ResultsTable table
	(
		txID int,
		txMID int,
		txTimestamp datetime,
		txGamingDate smalldatetime,
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
	
	insert into @ResultsTable
	(
		txID,
		txMID,
	 	txTimestamp, 
	 	txGamingDate,
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
	 	txValue
	)
	select it.ivtInvTransactionID,
		it.ivtMasterTransactionID ,
	    it.ivtInvTransactionDate, 
	    it.ivtGamingDate,
		it.ivtGamingSession,
		it.ivtStaffID,
		s.LastName + ', ' + s.FirstName,     -- DE7724
		ii.iiProductItemID,
		pri.ItemName,
		ii.iiSerialNo,
		it.ivtTransactionTypeID,
		tt.TransactionType,
		0,
		'',
		'',
		it.ivtStartNumber,
		it.ivtEndNumber,
		0,
		it.ivtPrice,
		0
	from InvTransaction it
	    join InventoryItem ii on (it.ivtInventoryItemID = ii.iiInventoryItemID)
		join ProductItem pri on (ii.iiProductItemID = pri.ProductItemID)
		join TransactionType tt on (tt.TransactionTypeID = it.ivtTransactionTypeID)
		join Staff s on (it.ivtStaffID = s.StaffID)
	where it.ivtGamingDate >= @StartDate
	    and it.ivtGamingDate < @EndDate
	    and it.ivtTransactionTypeID in (3, 23, 25, 27, 32)
	    and pri.ProductTypeID = 16 -- DE7241 - Only include paper products.
		and (@OperatorID = 0 or pri.OperatorID = @OperatorID)
		and (@Session = 0 or @Session = it.ivtGamingSession);

	-- Next, Update the Quantity from the detail record for the row specified
	DECLARE TempTableCursor CURSOR FOR
	SELECT txID FROM @ResultsTable;
	
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
			UPDATE @ResultsTable
			SET txStaff2 = (SELECT TOP 1 ilStaffID
							FROM InvLocations il
							JOIN InvTransactionDetail itd ON (il.ilInvLocationID = itd.ivdInvLocationID)
							WHERE itd.ivdInvTransactionDetailID = @TransDtlId
							ORDER BY itd.ivdDelta ASC)
			WHERE txID = @TmpIndex; 				
			
			-- Set the quantity into the table
			UPDATE @ResultsTable
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
			UPDATE @ResultsTable
			SET txStaff2 = (SELECT TOP 1 ilStaffID
							FROM InvLocations il
							JOIN InvTransactionDetail itd ON (il.ilInvLocationID = itd.ivdInvLocationID)
							WHERE itd.ivdInvTransactionDetailID = @TransDtlId
							ORDER BY itd.ivdDelta ASC)
			WHERE txID = @TmpIndex; 				
			
			-- Set the quantity into the table
			UPDATE @ResultsTable
			SET txQty = (SELECT ivdDelta
						 FROM InvTransactionDetail
						 WHERE ivdInvTransactionDetailID = @TransDtlId)
			WHERE txID = @TmpIndex;
		END
		
		FETCH NEXT FROM TempTableCursor INTO @TmpIndex;
	END
	
	CLOSE TempTableCursor;
	DEALLOCATE TempTableCursor;

	Update @ResultsTable
	SET txValue = txQty * txPrice;

	Update @ResultsTable
	SET txStaff2FirstName = s.FirstName,
		txStaff2LastName = s.LastName
	FROM @ResultsTable rt
		JOIN Staff s on (rt.txStaff2 = s.StaffID);
	
	IF @StaffID <> 0
	BEGIN
		DELETE FROM @ResultsTable
		WHERE txStaff2 <> @StaffID;
	END
	
	select 
		txID ,
		txMID ,
		txTimestamp ,
		txGamingDate,
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
	 from @ResultsTable rt
	 order by txGamingDate;










GO

