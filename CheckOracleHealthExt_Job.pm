package MyJob;

our @ISA = qw(DBD::Oracle::Server);

sub init {
  my $self = shift;
  my %params = @_;
  $self->{failing} = 0;
  $self->{broken} = 0;
  if ($params{mode} =~ /my::job::broken/) {
    ($self->{broken}, $self->{failing}) = 
        $self->{handle}->fetchrow_array(q{
          select 
            b_jobs as broken_jobs,
            f_jobs as failing_jobs
          from
            (select count(*) as b_jobs from DBA_JOBS where BROKEN = 'Y') broken,
            (select count(*) as f_jobs from DBA_JOBS where FAILURES > 1 and BROKEN = 'N') failures 
        });
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /my::job::broken/) {
    if ($self->{broken} >= 1) {
        my $level = $self->check_thresholds($self->{broken},0,0);
        $self->add_nagios($level, (sprintf "%d broken job(s)", $self->{broken}));
    } elsif ($self->{broken} == 0 && $self->{failing} >= 1) {
      $self->add_nagios_warning(sprintf "%d failing job(s)", $self->{failing});
    } else {
      $self->add_nagios_ok("All jobs are running well");
    }
    $self->add_perfdata(sprintf "broken=%d;%d;%d;0; failing=%d;;;0;", $self->{broken}, $self->{warningrange}, $self->{criticalrange}, $self->{failing});
  } else {
    $self->add_nagios_unknown("unknown mode");
  }
}
