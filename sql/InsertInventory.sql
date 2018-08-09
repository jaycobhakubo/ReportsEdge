-- Insert new report
Use Daily
Go

if not exists (select 1 from Reports where ReportFileName = 'Inventory.rpt')
begin
	Insert into Reports Values (13, 1, 'Inventory.Rpt') --Inventory

	Declare @ReturnValue int

	Select @ReturnValue = SCOPE_IDENTITY ()

	Insert into ReportDefinitions Values (1, @ReturnValue) --OperatorID

	Insert into ReportLocalizations Values (@ReturnValue, 1033, 'en-US', 'Inventory')
End
Go