USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[GetLastUnitSerialNumberByTransaction]    Script Date: 06/28/2012 09:41:46 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GetLastUnitSerialNumberByTransaction]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[GetLastUnitSerialNumberByTransaction]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[GetLastUnitSerialNumberByTransaction]    Script Date: 06/28/2012 09:41:46 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- ============================================================================
-- Author: jnolte
-- Create date: 6/27/2012
-- Description:	Returns the last unit serial number that a sale was loaded into
-- ============================================================================
CREATE function [dbo].[GetLastUnitSerialNumberByTransaction]
(
	@transactionNumber int
)
returns nvarchar(128)
as
begin
	declare @serialNumber nvarchar(128),
	    @registerReceiptId int
	
	select @registerReceiptId = case when OriginalReceiptId is not null then OriginalReceiptId
	                            else RegisterReceiptId end
	from RegisterReceipt
	where TransactionNumber = @transactionNumber
	    
    select @serialNumber = case
                when (len (rrXfer.UnitSerialNumber) > 0 and rrXfer.TransactionNumber = @transactionNumber) then rrXfer.UnitSerialNumber
                when m.SerialNumber is not null then m.SerialNumber
                when m.ClientIdentifier is not null then m.ClientIdentifier
                when len (ul.ulUnitSerialNumber) > 0 then ul.ulUnitSerialNumber
                else rrSale.UnitSerialNumber end
            from RegisterReceipt rrSale
                left join RegisterReceipt rrXfer on 
                    (rrSale.RegisterReceiptId = rrXfer.OriginalReceiptId and
                     rrXfer.TransactionTypeId = 14)                    
                left join UnlockLog ul on rrSale.RegisterReceiptId = ul.ulRegisterReceiptId
                left join Machine m on ul.ulSoldToMachineId = m.MachineId
            where rrSale.RegisterReceiptId = @registerReceiptId
                and (ul.ulId = (select max(ulId) from UnlockLog where ulRegisterReceiptid = rrSale.RegisterReceiptid) or ul.ulId is null)

	return @serialNumber
end




GO

