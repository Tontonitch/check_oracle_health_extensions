package MyLock;

our @ISA = qw(DBD::Oracle::Server);

sub init {
  my $self = shift;
  my %params = @_;
  $self->{results} = ();
  if ($params{mode} =~ /my::lock::blocking/) {
    my @results = $self->{handle}->fetchall_array(q{
		select 
			l.sid,
			decode(l.type,'TM','DML','TX','Trans','UL','User',l.type),
			decode(l.lmode,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share',5,'S/Row-X',6,'Exclusive', l.lmode),
			decode(l.request,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share',5,'S/Row-X',6,'Exclusive', l.request),
			l.ctime
		from v$lock l
		where l.block = 1
		order by l.ctime desc
		});
    my $count = 0;
    foreach (@results) {
      $self->{results}->{$count} = \@{$_};
      $count++;
    }
  } else {
    print "Mode not found";
  }
}

sub nagios {
  my $self = shift;
  my %params = @_;
  if ($params{mode} =~ /my::lock::blocking/) {
    my $nb_locks = 0;
	foreach (values %{$self->{results}}) {
		my($sid_session, $lock_type,$lock_mode, $lock_request, $lock_duration) = @{$_};
		my $level = $self->check_thresholds($lock_duration, 0, 120);
		if ($level == 2) {
			$self->add_nagios_critical(sprintf "sid=%d/type=%s/mode=%s/duration=%d", $sid_session, $lock_type, $lock_mode, $lock_duration);
			$nb_locks++;
		} elsif ($level == 1) {
			$self->add_nagios_warning(sprintf "sid=%d/type=%s/mode=%s/duration=%d", $sid_session, $lock_type, $lock_mode, $lock_duration);
			$nb_locks++;
		}
	}
	if ($nb_locks == 0) {
		$self->add_nagios_ok("no persistent locks detected");
	}
	$self->add_perfdata(sprintf "nb_locks=%d", $nb_locks);
  } else {
    $self->add_nagios_unknown("unknown mode");
  }
}
