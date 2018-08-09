USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventorySkipsReport]    Script Date: 04/24/2014 10:35:27 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventorySkipsReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventorySkipsReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventorySkipsReport]    Script Date: 04/24/2014 10:35:27 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE  [dbo].[spRptInventorySkipsReport] 
(
-- =============================================
-- Author:		Barry J. Silver
-- Description:	Lists missing (skipped) paper
--
-- BJS - 05/25/2011  US1747 new report
-- 2014.04.24 tmp: DE9169 Added Inventory Item ID so that products with duplicate serial numbers are grouped with the correct product.
-- 2014.04.24 tmp: DE11722 The audit number that was skipped is not returned.
-- =============================================
	@OperatorID	    AS INT,
	@StartDate	    AS DATETIME,
	@EndDate	    AS DATETIME,
	@SerialNumber   as nvarchar(60),
	@StaffID        as int
)
as
begin
    set nocount on;
    
    declare @Results table
    (
        itemID		int,			 --DE9169
        serialNo    nvarchar(30),
        manufId     int,
        manufName   nvarchar(64),
        rangeStart  int,
        rangeEnd    int,
        cardCutId   int,
        cardCutName nvarchar(10),
        up          int,
        skips       int,
        tranStart   int,
        tranEnd     int,
        itemName    nvarchar(64),
        prodTypeId  int,
        tranDate    datetime,
        staffId     int
    );

    insert into @Results
    select 
		ii.iiInventoryItemID		-- DE9169
      , ii.iiSerialNo
      , ii.iiManufacturerID, m.ManufacturerName
      , ii.iiRangeStart, ii.iiRangeEnd
      , ii.iiCardCutID, cc.ccCardCutName
      , ii.iiUp
	  , ivd.ivdDelta
      , ite.AuditNumber				-- DE11722
      , ite.AuditNumber				-- DE11722
      , pi.ItemName, pi.ProductTypeID
      , ivtInvTransactionDate, ivtStaffID
    from InventoryItem ii
    join InvTransaction ivt on ii.iiInventoryItemID = ivt.ivtInventoryItemID
    join InvTransactionExceptions ite on ivt.ivtMasterTransactionID = ite.InvMasterTransactionId	-- DE11722
	left join InvTransactionDetail ivd on ivt.ivtInvTransactionID = ivd.ivdInvTransactionID
    left join ProductItem pi on ii.iiProductItemID = pi.ProductItemID
    left join Manufacturer m on ii.iiManufacturerID = m.ManufacturerID
    left join CardCuts cc on ii.iiCardCutID = cc.ccCardCutID
    where 
    ivt.ivtTransactionTypeID in (23) -- skips
    and pi.ProductTypeID in (16)     -- paper
	and pi.OperatorID = @OperatorID	-- DE9152
    and (ivt.ivtGamingDate >= @StartDate and ivt.ivtGamingDate <= @EndDate) --DE9152
    and (@SerialNumber = '0' or ii.iiSerialNo = @SerialNumber)
    and (@StaffID = 0 or ivt.ivtStaffID = @StaffID)
	and ivd.ivdDelta <> 0
    order by ii.iiSerialNo, m.ManufacturerName;
    
    select * from @Results
    order by tranDate;

end;
set nocount off;















GO

