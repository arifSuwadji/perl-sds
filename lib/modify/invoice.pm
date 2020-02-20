package modify::invoice;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use common;

sub paid{
	my ($s,$q,$db,$log) = @_;

	my $inv_id = $q->param('inv_id');
	my $from =  $q->param('inv_date');
	my $until = $q->param('inv_date');
	my $outlet_id = $q->param('outlet_id');
	my $outlet_name = $q->param('outlet_name');
	my $amount = $q->param('amount');
	my $invoice_number = $q->param('invoice_number');
	my $type = $q->param('type');

	my $outlet_balance = $db->query("select balance from outlet where outlet_id=?", $outlet_id)->list;
	my $balance = $outlet_balance + $amount;
	
	$db->begin;
	# insert transaction
	$db->insert('transaction',{
		trans_type => $type,
		trans_date => \['curdate()'],
		trans_time => \['curtime()'],
		admin_id   => $s->{adm_id},
	});
	my $trans_id = $db->last_insert_id(0,0,0,0);
	
	#insert outlet_mutation
	$db->insert('outlet_mutation',{
		outlet_id => $outlet_id,
		trans_id  => $trans_id,
		balance   => $balance,
		mutation  => $amount,
	});
	
	#update invoice
	$db->update('invoice',
		{
			status   => 'paid',
			trans_id => $trans_id,
		},
		{
			inv_id   => $inv_id,
		}
	);
	
	#update outlet
	$db->update('outlet',
		{
			balance => $balance,
		},
		{
			outlet_id => $outlet_id,
		}
	);
	
	#compose message
	#insert into sms-inbox, use smsc-id = 1, user-id =1
	$db->insert("sms",{
		sms_int => \["concat('|[ paid for invoice number $invoice_number',' ]|')"],
		smsc_id => 1, sms_time => \['now()'],
		user_id => 1, sms_localtime => \['now()'],
		});
	my $sms_id = $db->last_insert_id(0,0,0,0);
	
	my $user_id = $db->query("select user_id from user where outlet_id=? and status='Active'", $outlet_id)->list;
	# insert into sms-outbox
	$db->insert('sms_outbox', {
		sms_id => $sms_id, user_id => $user_id, out_ts => \['now()'],
		out_msg => "Anda telah melakukan pelunasan invoice sebesar $amount dari no invoice:$invoice_number. Terimakasih",
		out_status => 'W',
	});
	
	$db->commit;

	return "/view/invoice/list?from=$from&until=$until&outlet_name=$outlet_name&status=PAID";
}

sub change_payment {
	my ($s,$q,$db,$log) = @_;

	my $trans_id = $q->param('trans_id');
	my $pay_type = $q->param('pay_type');
	my $inv_id = $q->param('inv_id');
	my $outlet_name = $q->param('outlet_name');
	my $today = common::today();
	my $note_bank = undef;

	eval{
		$db->begin;
		$db->query("update transaction set trans_type=? where trans_id=?", $pay_type, $trans_id);
		$db->query("update invoice set note_bank=? where inv_id=?", $note_bank, $inv_id);
		$db->commit;
	};
	if($@){
		$log->warn("error update transaction : ", $@);
	}
	if($pay_type eq 'paid_bank'){
		return "/view/invoice/note_payment?inv_id=$inv_id&outlet_name=$outlet_name";
	}
	return "/view/invoice/invoice_payment?from=$today&until=$today";
}


sub note_payment {
	my ($s,$q,$db,$log) = @_;

	my $inv_id = $q->param('inv_id');
	my $note_bank = $q->param('note_bank');
	my $today = common::today();

	eval{
		$db->begin;
		$db->query("update invoice set note_bank=? where inv_id=?", $note_bank, $inv_id);
		$db->commit;
	};
	if($@){
		$log->warn("error update invoice : ", $@);
	}

	return "/view/invoice/invoice_payment?from=$today&until=$today";
}

1;
