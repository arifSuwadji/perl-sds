package view::invoice;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub list {
	my ($s,$q,$db,$log) = @_;
	my $outlet_id = $q->param('outlet_id')||'';
	my $status = $s->param('status') ||'';
	my $from = $s->param('from');
	my $until = $s->param('until');

	my $pager = $s->q_pager(<<"EOS",
	select outlet_name, invoice.status, date_format(inv_date,'%d-%m-%Y') as inv_date, concat(outlet_id,'/',inv_date) as invoice_number, format(amount,2) as amount,
	date_format(due_date, '%d-%m-%Y') as due_date, inv_id, case invoice.status when 'unpaid' then 'cash' end as paid, member_name,
	case invoice.status when 'unpaid' then 'transfer' end as bank, amount as sum, outlet_id, inv_date<>due_date as check_invoice
from invoice 
	inner join outlet using (outlet_id)
	inner join member using (member_id)
EOS
	
	filter => {
		from => "inv_date >= str_to_date(?,'%d-%m-%Y')",
		until => 'inv_date < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
		outlet_name => "outlet_name like concat(?,'%')",
		status => "invoice.status = ?",
		member_name => "member_name = ?",
		},
	suffix => 'group by inv_id having check_invoice > 0 order by inv_id desc',
	);

	my $balance = $db->query("select format(sum(amount),0) from invoice where inv_date >= str_to_date(?,'%d-%m-%Y') and inv_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) and status='unpaid'",$from,$until)->list;
	return {
		list_outlet => $pager->{list},
		nav => $pager->{nav},
		outlet_id => $outlet_id,
		outlet_name => $q->param('outlet_name')||'',
		status1 => $status eq 'PAID',
  	    status2 => $status eq 'UNPAID',
		from => $from,
		until => $until,
		balance => $balance || '0.00',
		member_name => $s->param('member_name') || '',
	};
}

sub invoice_due{
	my ($s,$q,$db,$log) = @_;
	
	my $until = $q->param('until');

	my $res = $s->q_pager(<<"EOS",
		select date_format(inv_date,'%d-%m-%Y') as inv_date, date_format(due_date,'%d-%m-%Y') as due_date, outlet_name, outlet_id, 
		concat(outlet_id,'/',inv_date) as invoice_number, format(amount,2) as amount, inv_id,invoice.status='Unpaid' as status, member_name
from invoice
		inner join outlet using (outlet_id)
		inner join member using (member_id)
EOS
	filter => {
		until => 'due_date < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
		member_name => "member_name = ?",
	},
	suffix => 'having status > 0',
	);
	
	my $balance_due = $db->query("select format(sum(amount),0) from invoice where due_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) and status='unpaid'",$until)->list;
	return{
		list => $res->{list},
		nav => $res->{nav},
		until => $until,
		balance_due => $balance_due || '0.00',
		member_name => $s->param('member_name') || '',
	}
}

sub print{
	my ($s,$q,$db,$log) = @_;

	my $inv_id = $s->param('inv_id');
	my $outlet_id = $s->param('outlet_id');

	my $res = $s->q_pager(<<"EOS",
		select topup.trans_id, stock_ref_name, topup_qty,format(-mutation,2) as mutation 
from topup 
		inner join invoice using (inv_id) 
		inner join transaction transaction on transaction.trans_id = topup.trans_id 
		left join outlet_mutation outlet_mutation on outlet_mutation.trans_id = transaction.trans_id 
		inner join stock_ref using (stock_ref_id)
EOS
    filter => {
        inv_id => 'inv_id = ?',
    }
    );

	my($outlet_name, $member_name)= $db->query("select outlet_name, member_name from invoice inner join outlet using (outlet_id) inner join member using (member_id) where inv_id=?", $inv_id)->list;
	
	return{
		list => $res->{list},
		inv_id => $inv_id,
		inv_date => $db->query("select date_format(inv_date,'%d-%m-%Y') from invoice where inv_id=?", $inv_id)->list,
		due_date => $db->query("select date_format(due_date,'%d-%m-%Y') from invoice where inv_id=?", $inv_id)->list,
		amount => $db->query("select format(amount,2) from invoice where inv_id=?", $inv_id)->list,
		invoice_number => $db->query("select concat(outlet_id,'/',inv_date) from invoice where inv_id=?", $inv_id)->list,
		outlet_id => $outlet_id,
		outlet_name => $outlet_name,
		canvasser => $member_name,
		admin => $s->{username},
	}
}

sub invoice_payment{
	my ($s,$q,$db,$log) = @_;

	my $from = $q->param('from');
	my $until = $q->param('until');
	my $member_name = $q->param('member_name');
	my $site_id = $q->param('site_id');
	my $payment_type = $q->param('payment_type');

	my @type_options = (
			{value=>'paid_bank', display=>'Paid Bank'},
			{value=>'paid_cash', display=>'Paid Cash'},
			);
	$_->{selected} = $_->{value} eq ($s->param('payment_type')||'') ? 1:0 foreach @type_options;


	my $res = $s->q_pager(<<"EOS",
		select if(inv_date=due_date,'',date_format(inv_date,'%d-%m-%Y')) as inv_date, if(inv_date=due_date,'',date_format(due_date,'%d-%m-%Y')) as due_date,
		outlet_name, outlet_id, if(inv_date=due_date,'',concat(outlet_id,'/',inv_date)) as invoice_number, format(amount,2) as amount, inv_id, member_name,
		date_format(trans_date, '%d-%m-%Y')trans_date, trans_time, trans_id,
		case trans_type when 'paid_cash' then 'cash' when 'paid_bank' then 'transfer' end as trans_type,
		case trans_type when 'paid_cash' then 'paid_bank' when 'paid_bank' then 'paid_cash' end as change_type,
		if(note_bank is null, '', note_bank) as note_bank, site_name, site_id
from invoice
		inner join outlet using (outlet_id)
		inner join transaction using (trans_id)
		inner join member using (member_id)
		inner join site using (site_id)
EOS
	filter => {
		from  => 'trans_date >= str_to_date(?, "%d-%m-%Y")',
		until => 'trans_date < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
		member_name => "member_name = ?",
		site_id => "site_id = ?",
		payment_type => "trans_type = ?",
	},
	suffix => 'order by trans_id desc',
	);
	
	my $paid_cash = $db->query("select format(sum(amount),0) from invoice inner join transaction using (trans_id) inner join member using(member_id)
		where trans_date >= str_to_date(?, '%d-%m-%Y') and trans_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) 
			and invoice.status='paid' and trans_type='paid_cash' and member_name=?",$from,$until,$member_name)->list;
	
	my $paid_bank = $db->query("select format(sum(amount),0) from invoice inner join transaction using (trans_id) inner join member using(member_id) 
		where trans_date >= str_to_date(?, '%d-%m-%Y') and trans_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) 
			and invoice.status='paid' and trans_type='paid_bank' and member_name=?",$from,$until,$member_name)->list;

	my $balance_paid = $db->query("select format(sum(amount),0) from invoice inner join transaction using (trans_id) inner join member using(member_id) 
		where trans_date >= str_to_date(?, '%d-%m-%Y') and trans_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) and invoice.status='paid' and member_name=?",$from,$until, $member_name)->list;
	unless($member_name){
		$paid_cash = $db->query("select format(sum(amount),0) from invoice inner join transaction using (trans_id) inner join member using(member_id)
			where trans_date >= str_to_date(?, '%d-%m-%Y') and trans_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) 
			and invoice.status='paid' and trans_type='paid_cash'",$from,$until)->list;
	
		$paid_bank = $db->query("select format(sum(amount),0) from invoice inner join transaction using (trans_id) inner join member using(member_id) 
			where trans_date >= str_to_date(?, '%d-%m-%Y') and trans_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) 
			and invoice.status='paid' and trans_type='paid_bank'",$from,$until)->list;

		$balance_paid = $db->query("select format(sum(amount),0) from invoice inner join transaction using (trans_id) inner join member using(member_id) 
			where trans_date >= str_to_date(?, '%d-%m-%Y') and trans_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) and invoice.status='paid'",$from,$until)->list;
	}
	
	return{
		r_args => $s->{r}->args,
		list  => $res->{list},
		nav   => $res->{nav},
		from  => $from,
		until => $until,
		paid_cash => $paid_cash || '0.00',
		paid_bank => $paid_bank || '0.00',
		balance => $balance_paid || '0.00',
		member_name => $s->param('member_name') || '',
		site_id => $s->{site_id},
		type_options => \@type_options,
	};
}

sub invoice_report{
	my ($s,$q,$db,$log) = @_;
	
	my $until = $q->param('until');

	my $res = $s->q_pager(<<"EOS",
		select date_format(inv_date,'%d-%m-%Y') as inv_date, date_format(due_date,'%d-%m-%Y') as due_date, outlet_name, outlet_id, 
		concat(outlet_id,'/',inv_date) as invoice_number, format(amount,2) as amount, inv_id,invoice.status='Unpaid' as status, member_name
from invoice
		inner join outlet using (outlet_id)
		inner join member using (member_id)
EOS
	filter => {
		until => 'inv_date < date_add(str_to_date(?, "%d-%m-%Y"), interval 1 day)',
		member_name => "member_name = ?",
	},
	suffix => 'having status > 0',
	);
	
	my $balance = $db->query("select format(sum(amount),0) from invoice where inv_date < date_add(str_to_date(?, '%d-%m-%Y'), interval 1 day) and status='unpaid'",$until)->list;
	return{
		list => $res->{list},
		nav => $res->{nav},
		until => $until,
		balance => $balance || '0.00',
		member_name => $s->param('member_name') || '',
	}
}

sub cash_receipt{
	my ($s,$q,$db,$log) = @_;
	
	my $from = $q->param('from');
    my $until = $q->param('until');
	
	my $prev_balance = $db->query("select format(sum(amount),2) from invoice inner join transaction using (trans_id) where trans_date < str_to_date(?,'%d-%m-%Y') and trans_type='paid_cash'",$from)->list;
	my $cash_receipt = $db->query("select format(sum(amount),2) from invoice inner join transaction using (trans_id) where trans_date >= str_to_date(?,'%d-%m-%Y') and trans_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) and trans_type='paid_cash'",$from, $until)->list;
	my $total_cash   = $db->query("select format(sum(amount),2) from invoice inner join transaction using (trans_id) where trans_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) and trans_type='paid_cash'",$until)->list;
	
	return{
		prev_balance => $prev_balance || '0.00',
		cash_receipt => $cash_receipt || '0.00',
		total_cash   => $total_cash || '0.00',
		from         => $from,
		until        => $until,
	}
}

sub bank_receipt{
	my ($s,$q,$db,$log) = @_;
	
	my $from = $q->param('from');
    my $until = $q->param('until');
	
	my $prev_balance = $db->query("select format(sum(amount),2) from invoice inner join transaction using (trans_id) where trans_date < str_to_date(?,'%d-%m-%Y') and trans_type ='paid_bank'",$from)->list;
	my $bank_receipt = $db->query("select format(sum(amount),2) from invoice inner join transaction using (trans_id) where trans_date >= str_to_date(?,'%d-%m-%Y') and trans_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) and trans_type='paid_bank'",$from, $until)->list;
	my $total_bank   = $db->query("select format(sum(amount),2) from invoice inner join transaction using (trans_id) where trans_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) and trans_type='paid_bank'",$until)->list;
	
	return{
		prev_balance => $prev_balance || '0.00',
		bank_receipt => $bank_receipt || '0.00',
		total_bank   => $total_bank || '0.00',
		from         => $from,
		until        => $until,
	}
}

sub financial_report {
	my ($s,$q,$db,$log) = @_;
	
	my $from = $q->param('from');
    my $until = $q->param('until');

	my ($sale,$s_amount) = $db->query("select format(sum(amount),2),if(sum(amount),sum(amount),0) from invoice where inv_date >= str_to_date(?,'%d-%m-%Y') and 
							inv_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day)",$from,$until)->list;
	my ($payable_paid,$p_amount) = $db->query("select format(sum(amount),2),if(sum(amount),sum(amount),0) from invoice inner join transaction using (trans_id) 
							where trans_date >= str_to_date(?,'%d-%m-%Y') and trans_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) 
							and status ='paid' and inv_date <> due_date",$from,$until)->list;
	my ($payable_unpaid,$u_amount) = $db->query("select format(sum(amount),2),if(sum(amount),sum(amount),0) from invoice 
							where inv_date >= str_to_date(?,'%d-%m-%Y') and inv_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) 
							and status ='unpaid' and inv_date <> due_date",$from,$until)->list;
	my ($cash_receipt,$c_amount) = $db->query("select format(sum(amount),2),if(sum(amount),sum(amount),0) from invoice inner join transaction using (trans_id)
							where trans_date >= str_to_date(?,'%d-%m-%Y') and trans_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) 
							and trans_type='paid_cash'",$from, $until)->list;
	my ($bank_receipt,$b_amount) = $db->query("select format(sum(amount),2),if(sum(amount),sum(amount),0) from invoice inner join transaction using (trans_id) 
							where trans_date >= str_to_date(?,'%d-%m-%Y') and trans_date < date_add(str_to_date(?,'%d-%m-%Y'), interval 1 day) 
							and trans_type='paid_bank'",$from, $until)->list;
	
	my $total = $s_amount + $p_amount;
	my $total_else = $u_amount + $c_amount + $b_amount;
	my $sum = $db->query("select format(?,2)", $total)->list;
	my $sum_else = $db->query("select format(?,2)", $total_else)->list;
	
	return{
		sale => $sale || '0.00',
		from => $from,
		until => $until,
		payable_paid => $payable_paid || '0.00',
		payable_unpaid => $payable_unpaid || '0.00',
		cash_receipt => $cash_receipt || '0.00',
		bank_receipt => $bank_receipt || '0.00',
		sum => $sum || '0.00',
		sum_else => $sum_else || '0.00',
	}
}

sub note_payment {
	my ($s,$q,$db,$log) = @_;

	my $inv_id = $q->param('inv_id');
	my $outlet_name = $q->param('outlet_name');

	return {inv_id => $inv_id, outlet_name => $outlet_name}
}

1;
