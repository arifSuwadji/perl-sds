package daemon::trx;
use strict;
use warnings;

use Carp qw(croak);
use config;

sub new {
	my $class = shift;
	my $self  = {};

	@$self{qw/db topup_id/} = @_;
	# db       : mandatory
	# topup_id : OPTIONAL

	bless($self, $class);
	return $self;
}

sub db {
	my $self = shift;
	return $self->{db};
}

sub query {
	my ($self, $sql, @bind) = @_;

	my $res = eval { $self->db->query($sql, @bind) };
	croak $@ unless $res;
	return $res;
}

sub insert {
	my ($self, $table_name, $pairs) = @_;

	my $res = eval { $self->db->insert($table_name, $pairs) };
	croak $@ unless $res;
	return $res;
}

sub last_insert_id {
	my ($self) = @_;
	my $res = eval{ $self->db->last_insert_id(0,0,0,0) };
	croak $@ unless $res;
	return $res;
}

sub update {
	my ($self, $table_name, $set, $where) = @_;

	my $res = eval { $self->db->update($table_name, $set, $where) };
	croak $@ unless $res;
	return $res;
}

sub trx {
	my ($self, $trans_type, $admin_id, $trans_ref) = @_;

	$self->insert('transaction', {
		trans_type => $trans_type, trans_date => \['curdate()'], trans_time => \['curtime()'],
		admin_id   => $admin_id || undef,
		trans_ref  => $trans_ref,
	});
	$self->{trans_id} = $self->db->last_insert_id(undef, undef, 'transaction', 'trans_id');
}

sub trans_id {$_[0]->{trans_id}}


# Common steps :
#
# * Mengunci saldo member(-member)
# * Cek saldo(2) member bila perlu
# * Buat dan simpan record transaksi
# * Melakukan mutasi saldo member(2)
#

sub lock_member {
	my ($self, $member_id) = @_;

	return $self->query(
		"select member_id, member_name, member_balance, status ".
		"from member where member_id=? FOR UPDATE",
		$member_id,
	)->hash;
}

sub lock_outlet {
	my ($self, $outlet_id) = @_;

	my $row = $self->query(
		"select outlet_id, outlet_name, balance, plafond, outlet_type_id, nominal_quota, balance_nominal, qty_quota, balance_qty ".
		"from outlet where outlet_id=? FOR UPDATE",
		$outlet_id,
	)->hash;

	# 2x queries : so that outlet_type table is not locked
	$row->{period} = $self->query(
		'select period from outlet_type where outlet_type_id=?',
		$row->{outlet_type_id} )->list;

	return $row;
}

sub mutation {
	my ($self, $amount, $member) = @_;

	# bila transaksinya memindahkan saldo deposit dari A ke B,
	# dg A sbg pelaku transaksi, maka 2 step :
	#
	# $Request->mutation(-$amount)
	# $Request->mutation(+$amount, $member_id_B)
	#

	my $member_id   = $member->{member_id};
	my $old_balance = $member->{member_balance};
	my $new_balance = $old_balance + $amount;

	$self->update('member',
		{ member_balance => $new_balance },
		{ member_id => $member_id },
	);

	$self->insert('mutation', {
		trans_id  => $self->{trans_id},
		member_id => $member_id,
		amount    => $amount,
		balance   => $new_balance,
	});
}

sub outlet_mutation {
	my ($self, $amount, $outlet) = @_;

	my $outlet_id   = $outlet->{outlet_id};
	my $old_balance = $outlet->{balance};
	my $new_balance = $old_balance + $amount;

	$self->update('outlet',
		{ balance => $new_balance },
		{ outlet_id => $outlet_id },
	);

	$self->insert('outlet_mutation', {
		trans_id  => $self->{trans_id},
		outlet_id => $outlet_id,
		mutation  => $amount,
		balance   => $new_balance,
	});
}


# Spesifik utk tipe transaksi 'TOPUP' : error_msg, reversal
# =========================================================

sub error_msg {
	my ($self, $msg) = @_;

	$self->update('topup',
		{error_msg => $msg, need_reply => 1, topup_status => 'D'},
		{topup_id => $self->{topup_id}},
	);
	# in our document flow scheme,
	# table topup is the storage for documents or topup queue/records.
	# those records will then be APPROVED (an actual trx) or DROPPED
}

sub reversal {
	my ($self, $trans_id, $admin_id, $no_reply, $ops, $log) = @_;

	my $row =  $self->query(<<"__eos__", $trans_id,
SELECT topup_id, topup.member_id, member_balance, sd_stock_id,
  qty, topup_qty, amount, rs_id, outlet_id
FROM topup
  INNER JOIN member using (member_id)
  LEFT JOIN rs_chip using (rs_id)
  LEFT JOIN sd_stock using (sd_id, stock_ref_id)
  INNER JOIN mutation on topup.member_id=mutation.member_id
    and mutation.trans_id=topup.trans_id
WHERE topup.trans_id=? and topup_status in ('W','P','S')
FOR UPDATE
__eos__
	)->hash || croak "reversal: valid row not found.";

	$self->trx('rev', $admin_id, $trans_id);
	
	# balance mutation
	$self->mutation(-$row->{amount}, $row);

	# stock mutation
	my %stock_PK  = (sd_stock_id => $row->{sd_stock_id});
	my $topup_qty = $row->{topup_qty};

	if ($row->{sd_stock_id}) {
		my $new_qty  = $row->{qty} + $topup_qty;

		$self->update('sd_stock', {qty => $new_qty}, \%stock_PK);
		$self->insert('stock_mutation', {
			trans_id => $self->trans_id, %stock_PK, sm_ts => \['now()'],
			trx_qty => $topup_qty, stock_qty => $new_qty,
		});
	}

	# data stock rs dan outlet
	if($config::need_check_quota){
		$self->balance_quota($row->{outlet_id}, $row->{rs_id}, -$row->{amount}, $row->{topup_qty});
	}

	# reversal awal : unless no reply
	# resend : if no_reply dan topup_sms gak usah diisi
	# reversal kedua unless no reply dan topup_sms diisi
	# pertanyaan apakah topup_sms berarti ada reply? 
	#jika $no_reply = 1 berarti need_reply = 0
	#jika $no_reply = 0 berarti need_reply = 1
	unless ($no_reply) { #reversal
		
                $self->update('topup', #reversal pertama
                        {topup_status=>'R', need_reply=>1}, {trans_id=>$trans_id},
                );
		
		
		$log->warn("trans_id=$trans_id sukses reversal") if $log;
        } else {	#
                $self->update('topup',
        		{topup_status=>'R', need_reply=>0}, {trans_id=>$trans_id},);
                my $res_query = $self->query('select rs_id, member_id, stock_ref_id, topup_qty from topup where trans_id=?', $trans_id);
		my ($rs_id, $member_id, $stock_ref_id, $topup_qty) = $res_query->list;

        	$self->insert('topup', {
        	        member_id => $member_id, stock_ref_id => $stock_ref_id,
                	topup_qty => $topup_qty,       rs_id => $rs_id,
	                topup_ts  => \['now()'],
	        });

        	my $top_id = $self->last_insert_id(0,0,0,0);
		
		
		my $res_lagi = $self->query("select sms_id, sms_int, smsc_id, user_id from topup_sms inner join topup using(topup_id) inner join sms using(sms_id) where trans_id = $trans_id");
		my ($sms_id, $msg, $smsc_id, $user_id) = $res_lagi->list;

		$log->warn("resend, sms id = $sms_id");
		
		if ($sms_id) { 
			$self->insert("sms", {
					smsc_id=>$smsc_id, sms_int=>$msg, 
					user_id=>$user_id, sms_time=>\['now()'], 
					sms_localtime =>\['now()'],
			});

		        my $sms_id_baru = $self->last_insert_id(0,0,0,0);

			$self->insert('topup_sms', { topup_id=>$top_id, sms_id=>$sms_id_baru });
			
			$log->warn('topup_sms terisi');

		} else {
			$self->insert('admin_log', {
                         admin_id => $admin_id, page_id => 7, admin_log_ts => \['now()'],
	                });
        	        my $log_id = $self->last_insert_id(0,0,0,0);
			$self->insert('topup_web', {topup_id=>$top_id, admin_log_id=>$log_id});
		}
	}
}

sub balance_quota{
	my ($self, $outlet_id, $rs_id, $amount, $topup_qty) = @_;

	my ($quota_rs_nominal, $last_balance_nominal, $quota_rs_qty, $last_balance_qty) = $self->query('SELECT rs_nominal_quota, rs_balance_nominal, rs_qty_quota, rs_balance_qty FROM rs_chip WHERE rs_id=?',$rs_id)->list;
	$last_balance_nominal -= $amount;
	$last_balance_qty -= $last_balance_qty;
	my $outlet = $self->lock_outlet($outlet_id);
	#update rs_chip
	if($quota_rs_nominal > 0){
		$self->query("UPDATE rs_chip SET rs_balance_nominal=? WHERE rs_id=?", $last_balance_nominal, $rs_id);
	}
	if($quota_rs_qty > 0){
		$self->query("UPDATE rs_chip SET rs_balance_qty=? WHERE rs_id=?", $last_balance_qty, $rs_id);
	}
	#update outlet
	my $sum_balance_rs_nominal = $self->query('SELECT sum(rs_balance_nominal) FROM rs_chip WHERE outlet_id=?', $outlet->{outlet_id})->list;
	my $sum_balance_rs_qty = $self->query('SELECT sum(rs_balance_qty) FROM rs_chip WHERE outlet_id=?', $outlet->{outlet_id})->list;
	if($outlet->{nominal_quota} > 0){
		$self->query('UPDATE outlet SET balance_nominal=? WHERE outlet_id=?', $sum_balance_rs_nominal, $outlet->{outlet_id});
	}
	if($outlet->{qty_quota} > 0){
		$self->query('UPDATE outlet SET rs_balance_qty=? WHERE outlet_id=?',$sum_balance_rs_qty, $outlet->{outlet_id});
	}
}

1;

