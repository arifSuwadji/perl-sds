package session;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use CGI::Enurl;
use Carp qw(croak);
use Time::HiRes qw(gettimeofday);

use APR::UUID ();
use Apache2::Log ();
use Apache2::Cookie ();
use Apache2::RequestIO ();
use Apache2::RequestRec ();

use common ();

sub new {
	my $class = shift;
	my $self  = {};
	@$self{qw/r q db/} = my ($r, $q, $db) = @_;
	$self->{'log'} = my $log = $r->server->log();

	$r->headers_out->add('Cache-Control' => 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0');
	$r->headers_out->add('Pragma'  => 'no-cache');
	$r->headers_out->add('Expires' => 'Thu, 19 Nov 1981 08:52:00 GMT');

	bless($self, $class);
	my $c_in = $r->headers_in->{Cookie};
	return $self unless ($c_in and $c_in =~ /sdsSessID=\w+/);
	return $self unless my $cookie = Apache2::Cookie::Jar->new($r)->cookies('sdsSessID');

	@$self{qw/mem_id adm_id username adm_gid site_id ref_type_id/} = $db->query(<<"EOS"
select member_id, admin_id, admin_name, adm_gid, site_id, ref_type_id from admin
where session_id=? and last_access>timestampadd(minute, ?, now())
EOS
		, $cookie->value, -20)->list;
	#$log->warn("cookie : ", $cookie->value||'');
	#$log->warn("adm id: ", $self->{adm_id}||'');
	#$log->warn("username: ", $self->{username}||'');
	#$log->warn("adm gid: ", $self->{adm_gid}||'');
	return $self unless $self->{adm_id};
	
	# page id
	$self->{pg_id} = $db->query(
		'select page_id from page where path=?', $r->uri,
	)->list;

	# is allowed
	$self->{allowed} = $db->query(
		"select count(*) from page_map where adm_gid=? and page_id=?",
		$self->{adm_gid},$self->{pg_id},
	)->list;

	$db->query(
		'update admin set last_access=now() where admin_id=?', $self->{adm_id},
	);
	return $self;
}

sub q   { shift->{q}     }
sub db  { shift->{db}    }
sub log { shift->{'log'} }
sub adm_id { shift->{adm_id} }
sub adm_gid { shift->{adm_gid} }

sub access_log {
	"insert into () on duplicate key repeated=repeated+1"
}

sub login {
	my $self = shift;

	#$self->warn('uri is do-login');
	my $adm_id = $self->query(
		"select admin_id from admin where admin_name=? and admin_password=md5(?)",
		$self->q->param('username'), $self->q->param('password'),
	)->list;
	unless ($adm_id) {
		$self->log->warn("adm-id not found");
		return;
	}

	#$self->warn("adm-id found");
	my $sess_id = APR::UUID->new->format;
	my $c_out = Apache2::Cookie->new($self->{r},
		-name    => 'sdsSessID',
		-value   => $sess_id,
		-expires => '+1M',  #-expires => '+1m',
		-path    => '/'
		#-domain  => $r->connection->base_server->server_hostname,
	);
	$self->query(
		"update admin set last_access=now(), session_id=? where admin_id=?",
		$sess_id, $adm_id,
	);

   	$self->{r}->err_headers_out->add('Set-Cookie' => $c_out->as_string);
}


############## UTILITY METHODS ##########################

sub param {
	my ($self, @param_name) = @_;
	my @param_value;
	foreach(@param_name) {
		my @tmp_value = $self->{q}->param($_);
		push @param_value, (scalar(@tmp_value)? @tmp_value : undef);
	}
	return $param_value[0] if scalar(@param_name) ==1 and scalar(@param_value) == 1;
	return @param_value;
}

sub query {
	my ($self, $sql, @bind) = @_;

	my $res = eval { $self->{db}->query($sql, @bind) };
	croak $@ unless $res;
	return $res;
}

sub sql_list {
	my ($s, $sql, @bind) = @_;

	my $res = $s->query($sql, @bind);
	my ($i ,$row, @list) = (0);
	push @list, {_seq => ++$i, %$row} while $row = $res->hash;
	return \@list;
}

my $items_per_page  = 30;
my $pages_per_group = 10;

sub common_pager {
	my ($sess, $rows, $count2, $param) = @_;
	$param = $param ? ($param.'&') : '' ;

	my $page   = $sess->q->param('page')||1;
	my $pages  = POSIX::ceil($rows / $items_per_page);
	my $group  = POSIX::floor(($page-1)/$pages_per_group)+1;
	my $groups = POSIX::ceil($pages/$pages_per_group);

	my $r = $sess->{r};
	my $pager = "[";
	$pager .= ' <a href="'.$r->uri.'?'.$param.'page='.(($group-1)*$pages_per_group).'">&lt;&lt;</a>' if $group>1;
	for (my $i=$pages_per_group*($group-1)+1;$i<=$pages_per_group*$group;$i++) {
		last if $i>$pages;
		if ($page == $i) {
			$pager .= " $i";
			next;
		}
		$pager .= " <a href='".$r->uri.'?'.$param."page=$i'>$i</a>";
	}
	$pager .= ' <a href="'.$r->uri.'?'.$param.'page='.($group*$pages_per_group+1).'">&gt;&gt;</a>' if $group<$groups;
	$pager .= ' ]';

	return {
		items  => $rows,
		string => $pager,
		lower  => $items_per_page*($page-1),
		upper  => $items_per_page,
		count2 => $count2,
	};
}

sub pager {
	my ($sess, $sql, $param, $sql_param) = @_;

	my ($rows, $count2) = $sess->query($sql, @$sql_param)->list;
	return $sess->common_pager($rows, $count2, $param);
}

sub q_pager {
	my ($s, $sql, %attr) = @_;
	my ($tmp, @bind, @where, %link);
	croak('u gave me an empty/undefined $sql') unless $sql;

	my $param        = $attr{filter};
	my $suffix       = $attr{suffix};
	my $extra_param  = $attr{extra_param};
	my $extra_filter = $attr{extra_filter};
	my $sql_count    = $attr{sql_count};
	my $comma        = $attr{comma}; # array ref

	# from $s->param
	foreach (keys %$param) {
		if ($s->q->param($_)) {
			push @where, $param->{$_};
			$tmp = $param->{$_}; $tmp =~ s/[^?]//g; $tmp = length $tmp;
			for (my $i=0;$i<$tmp;$i++) {push @bind, $s->q->param($_)}
			$link{$_} = $s->q->param($_);
		}
	}
	$link{$_} = $s->q->param($_) foreach @$extra_param;

	# additional filter in where clause
	# $extra_param example : {
	# 	'member.site_id = ?' => $s->user_site_id,
	# 	'table.col_name between ? and ?' => $a_variable,
	# }
	foreach (keys %$extra_filter) {
		#$s->warn("got an extra filter: ", $_);
		next unless $extra_filter->{$_};
		#$s->warn("this extra filter is not empty");

		push @where, $_;
		$tmp = $_; $tmp =~ s/[^?]//g; $tmp = length $tmp;
		for (my $i=0;$i<$tmp;$i++) {push @bind, $extra_filter->{$_}}
	}

	my $start1 = gettimeofday;
	my $pager;

	# attr->{sql_count} sets additional aggregation,
	# e.g. select count(*), sum(col1)..
	# not a record count fixup due to "group by" suffix
	unless ($sql_count) {
		$sql =~ s/select/SELECT SQL_CALC_FOUND_ROWS/i;
		$sql_count = "SELECT FOUND_ROWS()";
		#$s->log->warn("auto-generated sql: ", $sql||'');
	}
	else {
		$sql_count .= "\nWHERE " . join(' and ', @where) if @where;
		$pager = $s->pager($sql_count, enurl(\%link), \@bind);
	}

	$sql .= "\nWHERE ". join(' and ', @where). "\n" if @where;
	$sql .= "\n".($suffix||'')."\nlimit ?, ?";
	#$s->log->warn("auto-generated sql: ", $sql||'');

	my $page = $s->q->param('page')||1;
	my ($seq, @list, $row) = ($items_per_page*($page-1));
	push @bind, $items_per_page*($page-1), $items_per_page;

	my $res = $s->query($sql, @bind);
	$pager = $s->pager($sql_count, enurl(\%link)) unless $attr{sql_count};
	$start1 = sprintf("%.2f", 1000*(gettimeofday-$start1));

	while ($row = $res->hash) {
		# commification
		foreach (@$comma) {
			next unless $row->{$_};
			$row->{$_} = common::commify($row->{$_});
		}

		push @list, {%$row, _seq => ++$seq};
	}

	my %return = (
		list => \@list,
		nav  => common::commify($pager->{items})." records in $start1 ms ".$pager->{string},
		page => $page,
		items_per_page => $items_per_page,
	);
	$return{count2} = $pager->{count2} if defined $pager->{count2};
	return \%return;
}


1;

