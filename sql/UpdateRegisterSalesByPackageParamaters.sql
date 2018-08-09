Use Daily;

Declare @ReturnValue int;

Select @ReturnValue = ReportID From Reports where ReportFileName = 'RegisterSalesByPackage.rpt'

If not exists (Select 1 From ReportDefinitions where ReportID = 211 and ReportParameterID = 5)
Begin
	Insert into ReportDefinitions values (5, @ReturnValue);
End