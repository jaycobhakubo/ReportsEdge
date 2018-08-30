use daily;
go
--BEGIN tran
declare @reporttypeid int; set @reporttypeid=null;
declare @reportid int; set @reportid=null;
declare @reportlocalid int; set @reportlocalid=null;
declare @reportparamid int; set @reportparamid=null;



select @reporttypeid =  Reporttypeid from ReportTypes where TypeName = 'Electronics';
select  @reportid = ReportID from Reports where ReportFileName = 'FortunetUnitUsage.rpt';
--select  ReportID from Reports where ReportFileName = 'FortunetUnitUsage.rpt'; -- 351
if (@reportid is null)
begin
	insert into Reports (IsActive, ReportFileName, ReportTypeID) values (1, 'FortunetUnitUsage.rpt', @reporttypeId);
	select @reportid = ReportID from Reports where ReportFileName = 'FortunetUnitUsage.rpt';
end;


select @reportlocalid = ReportLocalizationID from ReportLocalizations where ReportID = @reportid
--select ReportLocalizationID from ReportLocalizations where ReportID = 351
if (@reportlocalid is null)
begin
	insert into ReportLocalizations (ReportID, CultureID, CultureName, ReportDisplayName) values (@reportid, 1033, 'en-US', 'Fortunet Unit Usage Report');
end

select @reportparamid = ReportDefinitionID from ReportDefinitions where ReportID = @reportid;
--select  ReportDefinitionID from ReportDefinitions where ReportID = 351
if(@reportparamid is null)
begin
    insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 1); -- OperatorID
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 3); -- startdate
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, 4); -- enddate
end;
