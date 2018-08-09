use [daily]
go

if object_id('dbo.OccasionSchedulePullTab') is not null
begin
	alter table [dbo].[OccasionSchedulePullTab] drop constraint [fk_OccasionSchedulePullTab_OccasionScheduleType];
	alter table [dbo].[OccasionSchedulePullTab] drop constraint [fk_OccasionSchedulePullTab_OccasionSchedule];
	drop table [dbo].[OccasionSchedulePullTab];
end
go

set ansi_nulls on
go

set quoted_identifier on
go

create table [dbo].[OccasionSchedulePullTab](
	[OccasionSchedulePullTabID] [int] identity(1,1) not null,
	[OccasionScheduleID] [int] not null,
	[OccasionScheduleTypeID] [int] not null,
	[GameNo] [int] null,
	[FormNo] [nvarchar](32) null,
	[SerialNo] [nvarchar](32) null,
	[LargePrizes] [money] null,
	[SmallPrizes] [money] null,
	[LargePrizeFee] [money] null,
	[SmallPrizeFee] [money] null,
 constraint [PK_OccasionSchedulePullTab] primary key clustered 
(
	[OccasionSchedulePullTabid] asc
)with (pad_index = off, statistics_norecompute = off, ignore_dup_key = off, allow_row_locks = on, allow_page_locks = on) on [primary]
) on [primary];

go

alter table [dbo].[OccasionSchedulePullTab]  with check add  constraint [FK_OccasionSchedulePullTab_OccasionSchedule] foreign key([OccasionScheduleid])
references [dbo].[OccasionSchedule] ([OccasionScheduleID])
go

alter table [dbo].[OccasionSchedulePullTab] check constraint [FK_OccasionSchedulePullTab_OccasionSchedule]
go

alter table [dbo].[OccasionSchedulePullTab]  with check add  constraint [FK_OccasionSchedulePullTab_OccasionScheduleType] foreign key([OccasionScheduleTypeid])
references [dbo].[OccasionScheduleType] ([OccasionScheduleTypeID])
go

alter table [dbo].[OccasionSchedulePullTab] check constraint [FK_OccasionSchedulePullTab_OccasionScheduleType]
go


