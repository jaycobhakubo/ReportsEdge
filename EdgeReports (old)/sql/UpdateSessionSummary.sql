-- UpdateSessionSummary.sql

use Daily;
go

if (Exists(select * from sys.columns where Name = N'BingoOtherSales' and Object_ID = Object_ID(N'SessionSummary')))
begin
	print 'BingoOtherSales already exists, exiting.';
	return;
end;
--else
--begin
	print 'Adding BingoOtherSales column';
	alter table SessionSummary add BingoOtherSales money null;
	print 'Added';
	go

	print 'Initializing...';
	update SessionSummary set BingoOtherSales = 0;
	print 'Initialized';
	go

	alter table SessionSummary alter column BingoOtherSales money not null;
	print 'Done';
	go
--end;

