USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[GetLastUnitNumberByTransaction]    Script Date: 06/28/2012 09:41:32 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GetLastUnitNumberByTransaction]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[GetLastUnitNumberByTransaction]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[GetLastUnitNumberByTransaction]    Script Date: 06/28/2012 09:41:32 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- ============================================================================
-- Author: jnolte
-- Create date: 6/27/2012
-- Description:	Returns the last unit number that a sale was loaded into
-- ============================================================================
CREATE function [dbo].[GetLastUnitNumberByTransaction]
(
	@transactionNumber int
)
returns int
as
begin
	declare @unitNumber int,
	    @registerReceiptId int
	
	select @registerReceiptId = case when OriginalReceiptId is not null then OriginalReceiptId
	                            else RegisterReceiptId end
	from RegisterReceipt
	where TransactionNumber = @transactionNumber
	    
    select @unitNumber = case when nullif(rrXfer.UnitNumber, 0 ) is not null and rrXfer.TransactionNumber = @transactionNumber then rrXfer.UnitNumber
                when nullif(ul.ulUnitNumber,0) is not null then ul.ulUnitNumber
                when nullif(m.UnitNumber,0) is not null then m.UnitNumber
                when nullif(m.MachineId,0) is not null then m.MachineId       
                else rrSale.UnitNumber end
            from RegisterReceipt rrSale
                left join RegisterReceipt rrXfer on 
                    (rrSale.RegisterReceiptId = rrXfer.OriginalReceiptId and rrXfer.TransactionTypeId = 14)                    
                left join UnlockLog ul on rrSale.RegisterReceiptId = ul.ulRegisterReceiptId
                left join Machine m on ul.ulSoldToMachineId = m.MachineId
            where rrSale.RegisterReceiptId = @registerReceiptId
                and (ul.ulId = (select max(ulId) from UnlockLog where ulRegisterReceiptid = rrSale.RegisterReceiptid) or ul.ulId is null)

	return @unitNumber
end




GO

