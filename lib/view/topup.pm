package view::topup;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

#### edit secara berbarengan
sub edit_topup{
		my ($s,$q,$db,$log) = @_;
                #my $type = $s->sql_list('select stock_ref_id,stock_ref_name from stock_ref order by stock_ref_id');
                my $type = $s->sql_list('select stock_ref_id,stock_ref_name from topup_request inner join stock_ref using (stock_ref_id) where admin_id=? group by stock_ref_id order by stock_ref_id',$s->{adm_id});
                my $count_type = $s->sql_list('select count(*) as amounttype from stock_ref');
		my $count = $s->query('select count(*)+2 as colspan from stock_ref')->list;
                my @sql;
		
		my $rs_number = $q->param('rs_number')||'';
		$db->query('SET SESSION group_concat_max_len:=4294967295');
                my $res = $s->q_pager(<<"EOS",
select rs_id,rs_number,concat(\'<td>\',group_concat(\'<input id="topup_request" type=text name=\"\',rs_id,\'_\',stock_ref_id,\'\" value=\"\',ifnull(qty,\'0\') order by stock_ref_id separator \'\"></td><td>\'),\'\"></td>\') as qty from rs_chip inner join stock_ref inner join topup_request using(stock_ref_id,rs_id)
EOS
		filter => {rs_number=>"rs_number = ?",},
		extra_filter => {
			"topup_request.admin_id=?" => $s->{adm_id},
		},
		suffix => 'group by rs_id order by rs_id'
		);

		# my $res = $s->sql_list("select rs_id,rs_number,concat(\'<td>\',group_concat(\'<input id=\"topup_request\" type=text name=\"\',rs_id,\'_\',stock_ref_id,\'\", value=\"\',ifnull(qty,\'0\') order by stock_ref_id separator \'\"></td><td>\'),\'\"></td>\') as qty from rs_chip inner join stock_ref left join topup_request using(stock_ref_id,rs_id) group by rs_id limit 0,4"); suffix => 'order by sms_id desc',
		#my @list = @$res;
		#my $i=1;
		#foreach (@list) {
		#	$_->{seq} =$i;
		#	$i++; 
		#}
		
		my $list_jumlah = $s->sql_list("select stock_ref_id, group_concat(ifnull(qty,0)) as deret from topup_request 
						inner join stock_ref using(stock_ref_id)
						where admin_id=?
						group by stock_ref_id order by stock_ref_id",$s->{adm_id});
		
		my @array = @{$list_jumlah};
		foreach (@array) {
		
		my @array = split /,/, $_->{deret};
			$_->{sigma} = 0;
			for(my $x=0;$x<scalar(@array);$x++) {
				$_->{sigma} += $array[$x];
			}
		}
			
        return{
		count => $count,
                stock_name => $type,
                amount => $count_type,
                list => $res->{list},
		list_sigma => $list_jumlah,
		nav => $res->{nav},
		page => $res->{page},
		items => $res->{items_per_page},
		rs_number=>$rs_number,
        };

}

sub topup_upload {
	return {}
}
sub perdana_upload {
	return{}	
}
sub topup_rank {
	my ($s,$q,$db,$log) = @_;
	my $from = $q->param('from')||'';
	my $until = $q->param('until')||'';
	my $pager = $s->q_pager(<<"__eos__",
select summary_id, period_id, date_format(from_date,'%d-%m-%Y') as from_date, date_format(until_date,'%d-%m-%Y') as until_date, 
member_id, member_name, topup_summary, perdana_summary, perdana_qty,  
truncate(topup_summary / member_target * 100,2) as pers_nom, truncate(perdana_qty / target_qty * 100,2) as pers_perd from summary_sale 
inner join member using (member_id) inner join target_period using (period_id)
__eos__
	filter => {
	}, 
	extra_filter => {'period_status=?' => 'open',}, 
	suffix => 'order by pers_nom desc',
	comma => ['topup_summary', 'perdana_summary','pers_nom'],
	);

	return {
		r_args => $s->{r}->args,
		from => $from,
		until => $until,
		list => $pager->{list},
		nav => $pager->{nav},
	}
}
1;

