use Daily
go

if exists (select 1 from Reports where ReportFileName = 'ProgressiveSales.rpt')
begin 
	update	Reports 
	set		IsActive = 0, ReportTypeID = 16
	where	ReportFileName = 'ProgressiveSales.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SouthPointProgressiveSales.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'SouthPointProgressiveSales.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'ProgressiveJackpotCalendar.rpt')
begin 
	update	Reports
	set		IsActive = 1, ReportTypeID = 14
	where	ReportFileName = 'ProgressiveJackpotCalendar.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SouthPointProgressiveJackpotCalendar.rpt')
begin 
	update	Reports
	set		IsActive = 0, ReportTypeID = 16
	where	ReportFileName = 'SouthPointProgressiveJackpotCalendar.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SessionSummaryRecap.rpt')
begin 
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'SessionSummaryRecap.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SouthPointSessionSummaryRecapNoPercentages.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'SouthPointSessionSummaryRecapNoPercentages.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'BallCallReport.rpt')
begin 
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'BallCallReport.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SouthPointBallCallReport.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'SouthPointBallCallReport.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SouthPointProgressivePayouts.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'SouthPointProgressivePayouts.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'ElectronicUsageFeesSummary.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'ElectronicUsageFeesSummary.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'ProductSales.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'ProductSales.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SessionSummaryRecapCashBased.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'SessionSummaryRecapCashBased.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'SessionSummaryRecapDaily.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'SessionSummaryRecapDaily.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'CashActivityCashMethodPOS.rpt')
begin 
	update	Reports
	set		IsActive = 1
	where	ReportFileName = 'CashActivityCashMethodPOS.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'AccrualsActivityByAccount.rpt')
begin 
	update	Reports
	set		IsActive = 0, ReportTypeID = 16 
	where	ReportFileName = 'AccrualsActivityByAccount.rpt';
end

if exists (select 1 from Reports where ReportFileName = 'AccrualsBalancesReport.rpt')
begin 
	update	Reports
	set		IsActive = 0, ReportTypeID = 16 
	where	ReportFileName = 'AccrualsBalancesReport.rpt';
end

if exists (select 1 from Reports where ReportFileName = 'AccrualsDetailsReport.rpt')
begin 
	update	Reports
	set		IsActive = 0, ReportTypeID = 16 
	where	ReportFileName = 'AccrualsDetailsReport.rpt';
end

if exists (select 1 from Reports where ReportFileName = 'Acc2ConfigurationReport.rpt')
begin 
	update	Reports
	set		IsActive = 0, ReportTypeID = 16
	where	ReportFileName = 'Acc2ConfigurationReport.rpt';
end

if exists (select 1 from Reports where ReportID = 131)
begin
	update	Reports
	set		ReportFileName = 'SouthPointSessionSummaryReport.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'CannerySessionSummaryRecap.rpt')
begin
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'CannerySessionSummaryRecap.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'CannerySessionSummaryRecapCashBased.rpt')
begin
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'CannerySessionSummaryRecapCashBased.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'CannerySessionSummaryRecapDaily.rpt')
begin
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'CannerySessionSummaryRecapDaily.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'JerrysSessionSummaryRecap.rpt')
begin
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'JerrysSessionSummaryRecap.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'JerrysSessionSummaryRecapCashBased.rpt')
begin
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'JerrysSessionSummaryRecapCashBased.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'StationsProgressiveJackpotCalendar.rpt')
begin
	update	Reports
	set		IsActive = 0, ReportTypeID = 16
	where	ReportFileName = 'StationsProgressiveJackpotCalendar.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'StationsSessionSummaryRecap.rpt')
begin
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'StationsSessionSummaryRecap.rpt'
end

if exists (select 1 from Reports where ReportFileName = 'StationsSessionSummaryRecapDaily.rpt')
begin
	update	Reports
	set		IsActive = 0
	where	ReportFileName = 'StationsSessionSummaryRecapDaily.rpt'
end
