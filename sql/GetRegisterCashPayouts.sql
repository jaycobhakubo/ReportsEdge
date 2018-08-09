USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[GetRegisterCashPayouts]    Script Date: 01/04/2012 10:45:05 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GetRegisterCashPayouts]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[GetRegisterCashPayouts]
GO

USE [Daily]
GO

/****** Object:  UserDefinedFunction [dbo].[GetRegisterCashPayouts]    Script Date: 01/04/2012 10:45:05 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Barjinder Bal
-- Create date: 10/31/2011
-- Description:	Returns the total cash payouts
--				for a specified Register
--				
-- 2011.12.08 bjs: DE9573 improper use of params
-- 2012.01.04 bsb: ignoring the voids
-- =============================================
CREATE FUNCTION [dbo].[GetRegisterCashPayouts]
(
    @OperatorID int,
	@MachineID int,
	@StaffID int,
	@StartDate smalldatetime,
	@EndDate smalldatetime
)
returns money
AS
begin
	declare @CashPayouts money
	set @CashPayouts = '0.00'
	
	select @CashPayouts = @CashPayouts + ISNULL(SUM(ptdc.DefaultAmount), '0.00')	
	from PayoutTransDetailCash ptdc	
	join PayoutTrans pt ON (ptdc.PayoutTransID = pt.PayoutTransID)
	where (pt.GamingDate >= @StartDate AND pt.GamingDate <= @EndDate) -- DE9573
	and (@MachineID = 0 or pt.MachineID = @MachineID)
	and (@OperatorID = 0 or pt.OperatorID = @OperatorID)
	and (@StaffID = 0 or pt.StaffID = @StaffID)
    and pt.voidtransid is null;
    -- Return our resultset as a scalar
	return @CashPayouts;
end




GO
