USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventorySkipsReport]    Script Date: 08/23/2011 16:37:57 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[spRptInventorySkipsReport]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[spRptInventorySkipsReport]
GO

USE [Daily]
GO

/****** Object:  StoredProcedure [dbo].[spRptInventorySkipsReport]    Script Date: 08/23/2011 16:37:57 ******/
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
      ii.iiSerialNo
      , ii.iiManufacturerID, m.ManufacturerName
      , ii.iiRangeStart, ii.iiRangeEnd
      , ii.iiCardCutID, cc.ccCardCutName
      , ii.iiUp
      , ii.iiSkips      
      , ivt.ivtStartNumber
      , ivt.ivtEndNumber      
      , pi.ItemName, pi.ProductTypeID
      , ivtInvTransactionDate, ivtStaffID
    from InventoryItem ii
    join InvTransaction ivt on ii.iiInventoryItemID = ivt.ivtInventoryItemID
    left join ProductItem pi on ii.iiProductItemID = pi.ProductItemID
    left join Manufacturer m on ii.iiManufacturerID = m.ManufacturerID
    left join CardCuts cc on ii.iiCardCutID = cc.ccCardCutID
    where 
    ivt.ivtTransactionTypeID in (23) -- skips
    and pi.ProductTypeID in (16)     -- paper
    and (ivt.ivtGamingDate >= @StartDate and ivt.ivtGamingDate <= @EndDate) --DE9152
    and (@SerialNumber = '0' or ii.iiSerialNo = @SerialNumber)
    and (@StaffID = 0 or ivt.ivtStaffID = @StaffID)
    order by ii.iiSerialNo, m.ManufacturerName;
    
    select * from @Results
    order by tranDate;

end;
set nocount off;



GO


