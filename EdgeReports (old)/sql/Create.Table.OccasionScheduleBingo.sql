use [Daily]
go

if object_id('dbo.OccasionScheduleBingo') is not null
begin
	alter table [dbo].[OccasionScheduleBingo] drop constraint [FK_OccasionScheduleBingo_OccasionSchedule];
	drop table [dbo].[OccasionScheduleBingo];
end
go


set ansi_nulls on
go

set quoted_identifier on
go

create table [dbo].[OccasionScheduleBingo](
	[OccasionScheduleBingoID] [int] IDENTITY(1,1) NOT NULL,
	[OccasionScheduleID] [int] NOT NULL,
	[GameNbr] [int] NULL,
	[FullWinners] [int] NULL,
	[HalfWinners] [int] NULL,
	[PrizePerFullWinner] [money] NULL,
	[PrizePerHalfWinner] [money] NULL,
	[CashPrize] [money] NULL,
	[NonCashPrize] [money] NULL,
	[PrizeFee] [money] NULL,
 constraint [PK_OccasionScheduleBingo] primary key clustered 
(
	[OccasionScheduleBingoID] asc
)with (pad_index = off, statistics_norecompute = off, ignore_dup_key = off, allow_row_locks = on, allow_page_locks = on) on [primary]
) on [primary]

go

alter table [dbo].[OccasionScheduleBingo]  with check add  constraint [FK_OccasionScheduleBingo_OccasionSchedule] foreign key([OccasionScheduleID])
references [dbo].[OccasionSchedule] ([OccasionScheduleID]);
go

alter table [dbo].[OccasionScheduleBingo] check constraint [FK_OccasionScheduleBingo_OccasionSchedule];
go


