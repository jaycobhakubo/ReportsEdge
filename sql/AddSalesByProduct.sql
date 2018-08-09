use daily;
go

--begin tran

declare @reporttypeid int; set @reporttypeid=null;
declare @reportid int; set @reportid=null;
declare @reportlocalid int; set @reportlocalid=null;
declare @reportparamid int; set @reportparamid=null;

declare @p1 int;
declare @p2 int;
declare @p3 int;
declare @p4 int;
declare @p5 int;

select @p1 = ReportParameterID from ReportParameters where ParameterName = '@OperatorID';
select @p2 = ReportParameterID from ReportParameters where ParameterName = '@StartDate';
select @p3 = ReportParameterID from ReportParameters where ParameterName = '@EndDate';
select @p4 = ReportParameterID from ReportParameters where ParameterName = '@Session';
select @p5 = ReportParameterID from ReportParameters where ParameterName = '@StaffID';

--/*TEST if all parameter existes*/select * from reportparameters where ReportParameterID in (@p1,@p2,@p3, @p4, @p5)

select @reporttypeId = Reporttypeid from ReportTypes where TypeName = 'Sales';
select @reportid = ReportID from Reports where ReportFileName = 'SalesByProduct.rpt';

--/*TEST report Types*/ select * from reportTypes where TypeName = 'Sales'

if (@reportid is null)
begin
	insert into Reports (IsActive, ReportFileName, ReportTypeID) values (1, 'SalesByProduct.rpt', @reporttypeId);
	select @reportid = ReportID from Reports where ReportFileName = 'SalesByProduct.rpt';
end;


select @reportlocalid = ReportLocalizationID from ReportLocalizations where ReportID = @reportid
/*Why do the declare this variable if they are not going to use it @reportlocalid*/
--If we are only checking and assigning if its null then we do not need the upper script*/
if (@reportlocalid is null)
begin
	insert into ReportLocalizations (ReportID, CultureID, CultureName, ReportDisplayName) values (@reportid, 1033, 'en-US', 'Sales By Product');
end

select @reportparamid = ReportDefinitionID from ReportDefinitions where ReportID = @reportid;
if(@reportparamid is null)
begin
    insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p1); 
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p2); 
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p3);
	insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p4);
    insert into ReportDefinitions (ReportID, ReportParameterID) values (@reportid, @p5);
end;

--select * from Reports where ReportID = @reportid;
--select * from ReportDefinitions where ReportID = @reportid;
--select * from ReportLocalizations where ReportID = @reportid;

--select r.*, rd.*, rp.ParameterName, rl.*, rt.TypeName
--from reports r
--join ReportDefinitions rd on r.ReportID = rd.ReportID
--join ReportParameters rp on rd.ReportParameterID = rp.ReportParameterID
--join ReportLocalizations rl on r.ReportID = rl.ReportID
--join ReportTypes rt on rt.ReportTypeID = r.ReportTypeID
--where ReportFileName like 'SalesByProduct.rpt';


--commit tran