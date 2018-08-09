USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptTotalPointLiability]    Script Date: 12/19/2017 12:32:57 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptTotalPointLiability]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptTotalPointLiability]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptTotalPointLiability]    Script Date: 12/19/2017 12:32:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Travis Pollock
-- Create date: 20171219
-- Description:	Get the current outstanding point balance and outstanding value.
--              Use Point Value to set the dollar value of a point.
-- =============================================
CREATE procedure [dbo].[spRptTotalPointLiability]
	@OperatorID as int
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;
	
	declare @PointValue money
	set @PointValue = .02
	
	declare @SharePoints nvarchar(max)
	set @SharePoints =	(	select	SettingValue
							from	GlobalSettings
							where	GlobalSettingID = 180 -- Charities Share Points
						)

	declare @Results table
	(
		OutstandingBalance	money
		, OutstandingValue	money
	)
	
	if @SharePoints = 'True'	
	begin
		insert into @Results
		(
			OutstandingBalance
			, OutstandingValue
		)
		select	sum(pbPointsBalance)
				, sum(pbPointsBalance) * @PointValue
		from	PointBalances pb;
		
		select	*
		from	@Results;
	end		
	else
	begin
		insert into @Results
		(
			OutstandingBalance
			, OutstandingValue
		)
		select	sum(pbPointsBalance)
				, sum(pbPointsBalance) * @PointValue
		from	PointBalances pb
				join PlayerInformation pin on pin.PointBalancesID = pb.pbPointBalancesID
		where	pin.OperatorID = @OperatorID;
		
		select	*
		from	@Results;
	end
	
end


GO

