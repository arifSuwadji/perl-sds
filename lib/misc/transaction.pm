package misc::transaction;
use strict;
use warnings 'FATAL' => 'all';
no warnings 'redefine';
use PDF::API2;
use PDF::Table;
use Data::Dumper;

use constant mm => 25.4 / 72;
use constant in => 1 / 72;
use constant pt => 1;

sub list {
	my ($s) = shift;
	my $from = $s->param('from')||'';
	my $until= $s->param('until')||'';
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = <<"__eos__";
SELECT trans_id, topup_ts, keyword, rs_number, outlet_name,
  type_name as rs_type_name, sd_name, stock_ref_type.ref_type_name,
  site_name, topup_qty, format(price,0) as price, 
  topup_status, amount, member_name, error_msg, log_msg
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)

  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  LEFT JOIN stock_ref_type on sd_chip.ref_type_id=stock_ref_type.ref_type_id
  INNER JOIN site using (site_id)

  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
  LEFT JOIN pricing using(stock_ref_id,rs_type_id)
__eos__

	my %param = (
			from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
                        until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
                        type => "trans_type = ?",
                        keyword=> "keyword like concat('%',?,'%')",
                        rs_number => "rs_number = ?",
                        status => "topup_status = ?",
                        member_name => "member_name like concat('%',?,'%')",
                        admin_name => "admin_name like concat('%',?,'%')",
                        rs_type_id => "rs_chip.rs_type_id = ?",
                        site_id => "sd_chip.site_id = ?",
                        sd_name => "sd_name like concat('%',?,'%')",
                        sd_type_id => "sd_chip.ref_type_id =?",
                        outlet_id => "rs_chip.outlet_id = ?",
						outlet => "outlet_name like concat(?, '%')",
	);
	my (@where, @bind);
	foreach (keys %param) {
		if ($s->param($_)) {
			push @where, $param{$_};
			push @bind, $s->param($_);
		}
	}
		
	if (@where) {
		$sql .= "\n WHERE ";
		$sql .= join(" and ", @where);
	}

	$sql .= "\norder by trans_date desc, trans_time desc";
	my $log = $s->log();
        $log->warn($sql);
	
	my $res = $s->query($sql, @bind); $sql = '';
	while (my @row = $res->list) {
	#	$log->warn(scalar(@row));
		for (my $i=0;$i<scalar(@row);$i++) {
		$row[$i]='' unless defined($row[$i]);
		}
		$sql .= join("\t", @row)."\n";
	}
	
	return [$sql, 'application/vnd.ms-excel']
}

sub topup_report {
	my $s = shift;
	my $from = $s->param('from')||'';
	my $until= $s->param('until')||'';
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	
	my $sql;
        if ($s->{adm_gid} == 1) {
                $sql = "select keyword, sum(topup_qty) as keyword_sukses, sum(amount) as keyword_amount from transaction inner join mutation using(trans_id) left join topup using(trans_id) inner join stock_ref using(stock_ref_id) inner join rs_chip using(rs_id) left join sd_chip using(sd_id) inner join member on mutation.member_id = member.member_id left join admin on transaction.admin_id=admin.admin_id";
        } else {
                $sql = "select keyword, sum(topup_qty) as keyword_sukses from transaction inner join mutation using(trans_id) left join topup using(trans_id) inner join stock_ref using(stock_ref_id) inner join rs_chip using(rs_id) left join sd_chip using(sd_id) inner join member on mutation.member_id = member.member_id left join admin on transaction.admin_id=admin.admin_id";
        }

	my %param = (
		status_hidden => 'topup.topup_status=?',
                from => "transaction.trans_date >= str_to_date(?,'%d-%m-%Y')",
                until => "transaction.trans_date <= str_to_date(?,'%d-%m-%Y')",
                keyword => "stock_ref.keyword like concat('%',?,'%')",
                rs_number => "rs_chip.rs_number = ?",
                member_name => "member.member_name like concat('%',?,'%')",
                admin_name => "admin.admin_name like concat('%',?,'%')",
                sd_name => "sd_chip.sd_name like concat('%',?,'%')",
	);
	my (@where, @bind);
	foreach (keys %param) {
		if ($s->param($_)) {
			push @where, $param{$_};
			push @bind, $s->param($_);
		}
	}
		
	if (@where) {
		$sql .= "\n WHERE ";
		$sql .= join(" and ", @where);
	}

	$sql .= "\ngroup by stock_ref_id";
	my $log = $s->log();
        $log->warn($sql);
	
	my $res = $s->query($sql, @bind); $sql = '';
	while (my @row = $res->list) {
	#	$log->warn(scalar(@row));
		for (my $i=0;$i<scalar(@row);$i++) {
		$row[$i]='' unless defined($row[$i]);
		}
		$sql .= join("\t", @row)."\n";
	}
	
	return [$sql, 'application/vnd.ms-excel']
}
sub dep_list{
my ($s) = shift;
        my $from = $s->param('from')||'';
        my $until= $s->param('until')||'';
        return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
        my $sql = <<"__eos__",
SELECT trans_id, member_name, amount, balance, trans_date, trans_time,
  admin_name, out_ts, username, out_msg, out_status, smsc_name
FROM deposit_web
  INNER JOIN transaction using (trans_id)
  INNER JOIN mutation using (trans_id)
  INNER JOIN member using (member_id)

  INNER JOIN admin_log using (admin_log_id)
  INNER JOIN admin on admin.admin_id=admin_log.admin_id

  INNER JOIN user using (user_id)
  LEFT JOIN sms_outbox using (out_ts, user_id)
  LEFT JOIN smsc on sms_outbox.smsc_id=smsc.smsc_id
__eos__
		
		my %param  = (
                        from => "trans_date >= str_to_date(?,'%d-%m-%Y')",
                        until => "trans_date <= str_to_date(?,'%d-%m-%Y')",
                        member_name => "member_name =?",
                        trans_id => "trans_id=?",
        );
my (@where, @bind);
        foreach (keys %param) {
                if ($s->param($_)) {
                        push @where, $param{$_};
                        push @bind, $s->param($_);
                }
        }

        if (@where) {
                $sql .= "\n WHERE ";
                $sql .= join(" and ", @where);
        }

        $sql .= "\norder by trans_date desc, trans_time desc";
        my $log = $s->log();
        $log->warn($sql);

        my $res = $s->query($sql, @bind); $sql = '';
        while (my @row = $res->list) {
       $log->warn(scalar(@row));
               for (my $i=0;$i<scalar(@row);$i++) {
                    $row[$i]='' unless defined($row[$i]);
                     }
                 $sql .= join("\t", @row)."\n";
         }
          return [$sql, 'application/vnd.ms-excel']
}

sub dep_list {
	my ($s) = shift;
    my $from = $s->param('from')||'';
    my $until= $s->param('until')||'';
    return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = 'SELECT trans_id, member_name, amount, balance, trans_date, trans_time,
  admin_name, out_ts, username, out_msg, out_status, smsc_name
FROM deposit_web
  INNER JOIN transaction using (trans_id)
  INNER JOIN mutation using (trans_id)
  INNER JOIN member using (member_id)

  INNER JOIN admin_log using (admin_log_id)
  INNER JOIN admin on admin.admin_id=admin_log.admin_id

  INNER JOIN user using (user_id)
  LEFT JOIN sms_outbox using (out_ts, user_id)
  LEFT JOIN smsc on sms_outbox.smsc_id=smsc.smsc_id';
	my %param = (
                from => "trans_date >= str_to_date(?,'%d-%m-%Y')",
                until => "trans_date <= str_to_date(?,'%d-%m-%Y')",
                trans_id => "trans_id = ?",
                member_name=> "member_name like concat('%',?,'%')",
    );
	my (@where, @bind);
    foreach (keys %param) {
        if ($s->param($_)) {
            push @where, $param{$_};
            push @bind, $s->param($_);
        }
    }

    if (@where) {
        $sql .= "\n WHERE ";
        $sql .= join(" and ", @where);
    }

    $sql .= "\norder by trans_id desc";
    my $log = $s->log();
        $log->warn($sql);

    my $res = $s->query($sql, @bind); $sql = '';
    while (my @row = $res->list) {
	#   $log->warn(scalar(@row));
	for (my $i=0;$i<scalar(@row);$i++) {
        $row[$i]='' unless defined($row[$i]);
        }
        $sql .= join("\t", @row)."\n";
    }

    return [$sql, 'application/vnd.ms-excel']

}
sub list_pdf {
	my ($s) = shift;
	my $from = $s->param('from')||'';
	my $until= $s->param('until')||'';
	my $name = $s->param('member_name') || '';
	return [] unless $from =~ /\d\d-\d\d-\d{4}/ and $until =~ /\d\d-\d\d-\d{4}/;
	my $sql = <<"__eos__";
SELECT member_name, outlet_name, trans_id, topup_ts, keyword, rs_number, 
  type_name as rs_type_name, sd_name, stock_ref_type.ref_type_name,
  site_name, topup_qty,
  topup_status, amount
FROM topup
  INNER JOIN stock_ref using (stock_ref_id)

  INNER JOIN rs_chip using (rs_id)
  INNER JOIN outlet using(outlet_id)
  INNER JOIN rs_type using (rs_type_id)

  INNER JOIN sd_chip using (sd_id)
  LEFT JOIN stock_ref_type on sd_chip.ref_type_id=stock_ref_type.ref_type_id
  INNER JOIN site using (site_id)

  INNER JOIN member on member.member_id=topup.member_id

  LEFT JOIN transaction using (trans_id)
  LEFT JOIN mutation using (trans_id)

  LEFT JOIN sd_log using (log_id)
__eos__

	my %param = (
						from => "topup_ts >= str_to_date(?,'%d-%m-%Y')",
                        until => 'topup_ts < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
                        type => "trans_type = ?",
                        keyword=> "keyword like concat('%',?,'%')",
                        rs_number => "rs_number = ?",
                        status => "topup_status = ?",
                        member_name => "member_name like concat('%',?,'%')",
                        admin_name => "admin_name like concat('%',?,'%')",
                        rs_type_id => "rs_chip.rs_type_id = ?",
                        site_id => "sd_chip.site_id = ?",
                        sd_name => "sd_name like concat('%',?,'%')",
                        sd_type_id => "sd_chip.ref_type_id =?",
                        outlet_id => "rs_chip.outlet_id = ?",
						outlet => "outlet_name like concat(?, '%')",
	);
	my (@where, @bind);
    foreach (keys %param) {
        if ($s->param($_)) {
            push @where, $param{$_};
            push @bind, $s->param($_);
        }
    }
	if (@where) {
        $sql .= "\n WHERE ";
        $sql .= join(" and ", @where);
    }
	$sql .= "\norder by member_name, outlet_name, trans_id desc";
    my $log = $s->log();
        $log->warn($sql);

	my $res = $s->query($sql, @bind); $sql = join("\t", qw/NAME OUTLET ID DATE KEYWORD RO TYPE SUB-MASTER MATER-TYPE SITE QTY STATUS AMOUNT/) . "\n";
    while (my @row = $res->list) {
           for (my $i=0;$i<scalar(@row);$i++) {
                   $row[$i]='' unless defined($row[$i]);
           }
        $sql .= join("\t", @row)."\n";
     }
                                     
	my @line = split /\n/,$sql;
	my $nn;
	foreach my $no (0 .. $#line) {
		$nn .= $no ."\t".$line[$no].",";
	}
	$nn =~ s/^0/NO/ if $nn =~/^0/;
	my @lines = split/\,/,$nn;
	my @col;
	my @aoa;
	foreach (@lines){
		@col = split /\t/,$_;
		push @aoa,[@col];
	}
    $log->warn($sql);
	########################################################################################
	my $pdf = PDF::API2->new();
    my $page = $pdf->page;
    $pdf->mediabox(210 / mm, 297 / mm);
	my $pdftable = new PDF::Table;
    my %font = (
       Helvetica => {
            Bold   => $pdf->corefont( 'Helvetica-Bold',    -encoding => 'latin1' ),
            Roman  => $pdf->corefont( 'Helvetica',         -encoding => 'latin1' ),
            Italic => $pdf->corefont( 'Helvetica-Oblique', -encoding => 'latin1' ),
       },
       Times => {
            Bold   => $pdf->corefont( 'Times-Bold',   -encoding => 'latin1' ),
            Roman  => $pdf->corefont( 'Times',        -encoding => 'latin1' ),
            Italic => $pdf->corefont( 'Times-Italic', -encoding => 'latin1' ),
       },
    );
	my %set_table = (
	x => 20,
	w => 500,
	start_y => 800,
	start_h => 500,
	next_y  => 820,
	next_h  => 800,
	padding => 1,
	font => $pdf->corefont("Helvetica", -encoding => "latin1"),
	font_size => 8,
	justify => "center",
	padding_right => 1,
	background_color_odd  => "#e4e4e4",
	background_color_even => "#f5f5f5",
	);

	$pdftable->table($pdf, $page, \@aoa, %set_table);

	my $headline_text = $page->text;
    $headline_text->font( $font{'Helvetica'}{'Bold'}, '8/pt');
	$headline_text->translate(20, 830);
    $headline_text->text_center("from");
    $headline_text->translate(70, 830);
    $headline_text->text_center(": $from");
    $headline_text->translate(20, 820);
    $headline_text->text_center("until");
	$headline_text->translate(70, 820);
    $headline_text->text_center(": $until");
	$headline_text->translate(22, 810);
	$headline_text->text_center("name");
	$headline_text->translate(62, 810);
    $headline_text->text_center(": $name");

    my $text = $page->text;

	my $str = $pdf->stringify;
	return [$str, 'application/vnd.pdf']
}
1;

