-- Insert new report
Use Daily
Go

if not exists (select 1 from Reports where ReportFileName = 'DistributorFees.rpt')
begin
	Insert into Reports Values (8, 1, 'DistributorFees.Rpt') --Inventory

	Declare @ReturnValue int

	Select @ReturnValue = SCOPE_IDENTITY ()

	Insert into ReportDefinitions Values (1, @ReturnValue) --OperatorID
	
	Insert into ReportDefinitions Values (3, @ReturnValue) --EndDate
	
	Insert into ReportDefinitions Values (4, @ReturnValue) --StartDate 

	Insert into ReportLocalizations Values (@ReturnValue, 1033, 'en-US', 'Distributor Fees')
End
Go