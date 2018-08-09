-- Insert new report
Use Daily
Go

if not exists (select 1 from Reports where ReportFileName = 'InventoryEntryByInvoice.rpt')
begin
	Insert into Reports Values (13, 1, 'InventoryEntryByInvoice.Rpt') --Inventory

	Declare @ReturnValue int

	Select @ReturnValue = SCOPE_IDENTITY ()

	Insert into ReportDefinitions Values (1, @ReturnValue) --OperatorID

	Insert into ReportDefinitions Values (3, @ReturnValue) --StartDate

	Insert into ReportDefinitions Values (4, @ReturnValue) --EndDate

	Insert into ReportLocalizations Values (@ReturnValue, 1033, 'en-US', 'Inventory Entry by Invoice')
End
Go