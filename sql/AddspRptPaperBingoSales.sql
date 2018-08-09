use daily;
go

declare @reporttypeid int; set @reporttypeid=null;
declare @reportid int; set @reportid=null;
declare @reportlocalid int; set @reportlocalid=null;
declare @reportparamid int; set @reportparamid=null;

declare @p1 int;
declare @p2 int;
declare @p3 int;

select @p1 = ReportParameterID from ReportParameters where ParameterName = '@operatorID';
select @p2 = ReportParameterID from ReportParameters where ParameterName = '@StartDate';
select @p3 = ReportParameterID from ReportParameters where ParameterName = '@Session';




select @reporttypeId = Reporttypeid from ReportTypes where TypeName = 'Sales';
select @reportid = ReportID from Reports where ReportFileName = 'PaperBingoSales.rpt';

if (@reportid is null)
begin
	insert into Reports (IsActive, ReportFileName, ReportTypeID) values (1, 'PaperBingoSales.rpt', @reporttypeId);
	select @reportid = ReportID from Reports where ReportFileName = 'PaperBingoSales.rpt';
end;


select @reportlocalid = ReportLocalizationID from ReportLocalizations where ReportID = @reportid
if (@reportlocalid is null)
begin
	insert into ReportLocalizations (ReportID, CultureID, CultureName, ReportDisplayName) values (@reportid, 1033, 'en-US', 'Paper Bingo Sales');
end

select @reportparamid = ReportDefinitionID from ReportDefinitions where ReportID = @reportid;
if(@reportparamid is null)
begin
    insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p1); -- OperatorID
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p2); -- session
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p3); -- startdate


end;

select * from Reports where ReportID = @reportid;
select * from ReportDefinitions where ReportID = @reportid;
select * from ReportLocalizations where ReportID = @reportid;

select r.*, rd.*, rp.ParameterName, rl.*, rt.TypeName
from reports r
join ReportDefinitions rd on r.ReportID = rd.ReportID
join ReportParameters rp on rd.ReportParameterID = rp.ReportParameterID
join ReportLocalizations rl on r.ReportID = rl.ReportID
join ReportTypes rt on rt.ReportTypeID = r.ReportTypeID
where ReportFileName like 'PaperBingoSales.rpt';

