-- Insert new report
Use Daily
Go

if not exists (select 1 from Reports where ReportFileName = 'InvoicesSkips.rpt')
begin
	Insert into Reports Values (13, 1, 'InvoicesSkips.Rpt')

	Declare @ReturnValue int

	Select @ReturnValue = SCOPE_IDENTITY ()

	Insert into ReportDefinitions Values (1, @ReturnValue)

	Insert into ReportDefinitions Values (3, @ReturnValue)

	Insert into ReportDefinitions Values (4, @ReturnValue)

	Insert into ReportLocalizations Values (@ReturnValue, 1033, 'en-US', 'Invoices Skips')
End
Go