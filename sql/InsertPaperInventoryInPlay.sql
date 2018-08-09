-- Insert new report
Use Daily
Go

if not exists (select 1 from Reports where ReportFileName = 'PaperInventoryInPlay.rpt')
begin
	Insert into Reports Values (13, 1, 'PaperInventoryInPlay.Rpt') --Inventory

	Declare @ReturnValue int

	Select @ReturnValue = SCOPE_IDENTITY ()

	Insert into ReportDefinitions Values (1, @ReturnValue) --OperatorID

	Insert into ReportLocalizations Values (@ReturnValue, 1033, 'en-US', 'Paper Inventory - In Play')
End
Go