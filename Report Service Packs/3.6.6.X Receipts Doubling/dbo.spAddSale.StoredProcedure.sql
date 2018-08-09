USE [Daily]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spAddSale]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spAddSale]
GO

USE [Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[spAddSale]
--=============================================================================
-- ????.??.?? ??? Initial implementation
-- 2017.07.10 DE13652 There is an issue when the POS would receive an error 
--  during a transaction, then the transaction was completed without restarting
--  the transaction the detail items would be duplicated.
--=============================================================================
	@RegisterReceiptIdInput INT,
	@StaffID INT,
	@OperatorID INT,
	@DeviceID INT,
	@PlayerID INT,
	@TransactionTypeID INT,
	@SoldFromMachineID INT,
	@PackNumber INT,
	@AmountTendered NVARCHAR(16),
	@QualifyingAmount NVARCHAR(16),
	@PointsFromQualifying NVARCHAR(16),
	@SoldToMachineID INT = NULL,
	@BankID INT = NULL,
	@SalesCurrencyISOCode nvarchar(3) = N'USD'
AS
SET NOCOUNT ON

DECLARE @RegisterReceiptID int,
	@TransactionNumber int,
	@DeviceFee money,
	@UnitNumber smallint,
	@UnitSerialNumber varchar(30),
	@dtGamingDate smalldatetime,
	@DefaultCurrencyISOCode nvarchar(3)

SET @dtGamingDate = dbo.GetCurrentGamingDate()

--Initialize
select @DefaultCurrencyISOCode = N'USD'

--Get the Default Currency ISO Code
select @DefaultCurrencyISOCode = crhISOCode
from CurrencyHeader (nolock)
where crhIsDefault = 1

-- Convert zero to NULL
SET @DeviceID = NullIf (@DeviceID, 0)
SET @PlayerID = NullIf (@PlayerID, 0)
SET @SoldToMachineID = NullIf (@SoldToMachineID, 0)
SET @BankID = NullIf (@BankID, 0)
SET @RegisterReceiptIdInput = NullIf (@RegisterReceiptIdInput, 0)

if @SoldToMachineID IS NULL
begin
	SET @UnitNumber = NULL
	SET @UnitSerialNumber = NULL
end
else
begin
	select @UnitNumber = UnitNumber, 
		@UnitSerialNumber = LEFT(SerialNumber, 30),
		@DeviceID = DeviceID
	from Machine (nolock)
	where MachineID = @SoldToMachineID
end

select @DeviceFee = 0.00

-- DETERMINE IF THIS IS A TRUE START SALE...
IF (@RegisterReceiptIdInput IS NOT NULL)
BEGIN
    -- Since a register receipt was provided make sure that all of the associated
    --  that was associated with this is removed prior to attempting to insert it
    --  again this was causing an issue when there would be an error during a
    --  transaction items could be added multiple times for a single transaction
    DELETE FROM RegisterDetailItemAccruals
    WHERE RegisterDetailItemId IN (SELECT RegisterDetailItemId FROM RegisterDetailItems
                                    WHERE RegisterDetailId IN (SELECT RegisterDetailId FROM RegisterDetail
                                    WHERE RegisterReceiptId = @RegisterReceiptIdInput))
    
    DELETE FROM RegisterDetailItems
    WHERE RegisterDetailId IN (SELECT RegisterDetailId FROM RegisterDetail
                               WHERE RegisterReceiptId = @RegisterReceiptIdInput)
    
    DELETE FROM RegisterDetail WHERE RegisterReceiptId = @RegisterReceiptIdInput

	UPDATE [RegisterReceipt]
	SET [StaffID] = @StaffID
		,[OperatorID] = @OperatorID
		,[SoldFromMachineID] = @SoldFromMachineID
		,[DeviceID] = @DeviceID
		,[SoldToMachineID] = @SoldToMachineID
		,[PlayerID] = @PlayerID
		,[TransactionTypeID] = @TransactionTypeID
		,[GamingDate] = @dtGamingDate
		,[PackNumber] = @PackNumber
		,[DeviceFee] = @DeviceFee
		,[UnitNumber] = @UnitNumber
		,[AmountTendered] = @AmountTendered
		,[UnitSerialNumber] = @UnitSerialNumber
		,[BankID] = @BankID
		,[SalesCurrencyISOCode] = @SalesCurrencyISOCode
		,[DefaultCurrencyISOCode] = @DefaultCurrencyISOCode
		,[PointQualifyingAmount] = @QualifyingAmount
		,[PointsFromQualifyingAmount] = @PointsFromQualifying
	WHERE [RegisterReceiptID] = @RegisterReceiptIdInput;
	
	SET @RegisterReceiptID = @RegisterReceiptIdInput;
	
	SELECT @TransactionNumber = [TransactionNumber]
	FROM [RegisterReceipt]
	WHERE [RegisterReceiptID] = @RegisterReceiptIdInput;

END
ELSE
BEGIN
	-- Get the Transaction Number
	exec spGetTransactionNumber @OperatorID, 'Register', @TransactionNumber OUTPUT

	-- Increment the Player Visits count
	UPDATE PlayerInformation
	SET VisitCount = VisitCount + 1,
		LastVisitDate = @dtGamingDate
	WHERE PlayerID = @PlayerID
	AND OperatorID = @OperatorID
	AND (LastVisitDate IS NULL OR LastVisitDate < @dtGamingDate)

	-- Insert the sale data
	INSERT RegisterReceipt
			(StaffID,
			OperatorID,
			SoldToMachineID,
			DeviceID,
			PlayerID,
			TransactionTypeID,
			GamingDate,
			TransactionNumber,
			SoldFromMachineID,
			PackNumber,
			DeviceFee,
			AmountTendered,
			PointQualifyingAmount,
			PointsFromQualifyingAmount,
			UnitNumber,
			UnitSerialNumber,
			BankID,
			SalesCurrencyISOCode,
			DefaultCurrencyISOCode)
	VALUES
			(@StaffID,
			@OperatorID,
			@SoldToMachineID,
			@DeviceID,
			@PlayerID,
			@TransactionTypeID,
			@dtGamingDate,
			@TransactionNumber,
			@SoldFromMachineID,
			@PackNumber,
			@DeviceFee,
			@AmountTendered,
			@QualifyingAmount,
			@PointsFromQualifying,
			@UnitNumber,
			@UnitSerialNumber,
			@BankID,
			@SalesCurrencyISOCode,
			@DefaultCurrencyISOCode)
			
	SET @RegisterReceiptID = SCOPE_IDENTITY()

END

SELECT @RegisterReceiptID AS RegisterReceiptID, 
		@TransactionNumber AS TransactionNumber

SET NOCOUNT OFF
GO
