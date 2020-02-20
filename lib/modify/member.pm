package modify::member;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use config();

sub add_member {
	my ($s,$q,$db,$log) = @_;
	my $member_name = $q->param('member_name')||'';
	my $upline_name = $q->param('upline_name')||'';
	my $target = $q->param('target')||'';
	my $site_id = $q->param('site_id')||'';
	my $status = $q->param('status')||'';
	my $type = $q->param('type')||'';
	my $upline_id = $db->query('select member_id from member where member_name=?', $upline_name)->list;
	if($s->{ref_type_id}){
		if($s->{ref_type_id} eq 1){
			unless ($upline_id) {return '/view/member/add_member?error_msg=Upline+name+not+found';}
		}
	}
	$db->insert('member', { member_name => $member_name,
				parent_id => $upline_id,
				member_target => $target,
				member_type => $type,
				site_id=> $site_id,
				status=> $status,
			      });
	return '/view/member/list';
}

sub add_username {
	my ($s,$q,$db,$log) = @_;
	my $member_id = $q->param('id');
	my $member_name = $q->param('member_name');
	my $username = $q->param('username');
	my $user_id = $db->query('select user_id from user where username=?',$username)->list;
	return "/view/member/detail_member?id=$member_id&member_name=$member_name&error=username_exist" if (defined($user_id));

	my $pin = $q->param('pin');
	my $status = $q->param('status');
	$db->insert('user', { member_id => $member_id,
			      username => $username,
			      pin => $pin,
			      status=> $status,
			    });
	return "/view/member/detail_member?id=$member_id&member_name=$member_name";
}

sub edit_member {
	my ($s, $q, $db, $log) = @_;
	my $member_name = $q->param('member_name')||'';
	my $upline_name = $q->param('upline_name')||'';
	my $target = $q->param('target')||'';
	my $member_id = $q->param('member_id');
	my $site_id = $q->param('site_id');
	my $type = $q->param('type');
	if ($q->param('op') eq 'Add') {
		if ($q->param('add_product') and $q->param('add_product' =~ /^Dompul/)) {
			my $ref_type_id = $db->query("select max(ref_type_id+1) from stock_ref_type")->list;
			$db->insert('stock_ref_type',{
                    ref_type_name => $q->param('add_product'),
					ref_type_id => $ref_type_id,
                });
		}
		return "/view/member/edit_member?id=$member_id";		
	} elsif ($q->param('op') eq 'Update qty') {
		if ($config::adm_gid ne $s->{adm_gid}) {return "/view/member/edit_member?id=$member_id&errormsg=anda+tidak+punya+akses";}
		my @stock_s = $s->param('cb_stock');
		foreach (@stock_s){
			my $dt_id = $db->query('select dt_id from dompul_target where member_id=? and ref_type_id=?',$member_id, $_)->list;	
			unless ($dt_id) {
				$db->insert('dompul_target',{
					member_id => $member_id,
					ref_type_id => $_,
					qty_target => $q->param("stock$_"),
				});
			} else {
				$db->query(
				"update dompul_target set qty_target=? where member_id=? and ref_type_id=?",
				$q->param("stock$_"), $member_id, $_,
				);
			}
		}	
		return "/view/member/list";
	}

	my $upline_id = $db->query('select member_id from member where member_name=?', $upline_name)->list;
	if($s->{ref_type_id}){
		if($s->{ref_type_id} eq 1){
			unless ($upline_id) {return '/view/member/add_member?error_msg=Upline+name+not+found';}
			$s->query('update member set member_name=?, parent_id=?, site_id=?, member_type=?, member_target=? where member_id=?',$member_name, $upline_id, $site_id, $type, $target, $member_id);
		}else{
			$s->query('update member set member_name=?, site_id=?, member_type=?, member_target=? where member_id=?',$member_name, $site_id, $type, $target, $member_id);
		}
	}else{
		$s->query('update member set member_name=?, site_id=?, member_type=?, member_target=? where member_id=?',$member_name, $site_id, $type, $target, $member_id);

	}
	return '/view/member/list';
}

sub edit_dompul_name {
    my ($s, $q, $db, $log) = @_;
	my $id = $q->param('id');
	my $name = $q->param('rt_name');
	$db->query("update stock_ref_type set ref_type_name=? where ref_type_id=?",$name, $id);		
	return "/view/member/list?status=Active";
}

sub ubah_status {
        my ($s, $q, $db, $log) = @_;
        my $member_name = $q->param('member_name');
        my $member_id = $q->param('member_id');
	my $user_id = $q->param('user_id');
	my ($status) = $db->query('select status from user where user_id=?', $user_id)->list;
	my $new_status;
	if ($status eq 'Active') {
		$new_status=2;
	}
	else {
		$new_status=1;
	}
	$log->warn("update user set status=$new_status where user_id=$user_id");
        $s->query('update user set status=? where user_id=?',$new_status,$user_id);
        return "/view/member/detail_member?id=$member_id&member_name=$member_name";
}

sub change_status_member {
	my ($s, $q, $db, $log) = @_;
	my $member_id = $q->param('member_id');
	my $status;
	if ($q->param('status') eq 'Active') {
		$status = 2;
	} else {	
		$status = 1;
	}
	
	$db->query('update member set status = ? where member_id = ?', $status, $member_id);
	return "/view/member/list";
}

sub set_status {
	my ($s, $q, $db, $log) = @_;
	my @member_id = $q->param('member_id');
	my $status;
	if ($q->param('submit') eq 'Active') {
		$status = 1;
	} elsif ($q->param('submit') eq 'non-Active') {
		$status = 2;
	}
	foreach (@member_id) {
		$db->query('update member set status=? where member_id=?', $status, $_);
	}
	return "/view/member/list";
}

sub delete {
	my ($s, $q, $db, $log) = @_;
	my $member_id = $q->param('id')||'';
	$s->query('delete from member where member_id=?',$member_id);
	return '/view/member/list';
}

sub delete_username {
	my ($s, $q, $db, $log) = @_;
	my $member_id = $q->param('member_id')||'';
	my $member_name = $q->param('member_name')||'';
	my @user_id = $q->param('user_id');
#	$log->warn(@user_id);
	foreach (@user_id) {	
#		$log->warn($_);
		$s->query('delete from user where user_id =?', $_);
	}
	return "/view/member/detail_member?id=$member_id&member_name=$member_name";
}

sub set_target_period {
	my ($s, $q, $db, $log) = @_;
	my $from = $q->param('from');
	my ($tgl) = ($from =~ /^(\d+)-/);
	my ($thn) = ($from =~ /-(\d+)$/);
	my ($bln) = ($from =~ /-(\d+)-/);
	my $new = $thn.'-'.$bln.'-'.$tgl;
	my $until = $q->param('until');
	my ($tgl1) = ($until =~ /^(\d+)-/);
	my ($thn1) = ($until =~ /-(\d+)$/);
	my ($bln1) = ($until =~ /-(\d+)-/);
	my $new1 = $thn1.'-'.$bln1.'-'.$tgl1;
	$log->warn("from ",$new);
	$log->warn("until ",$new1);
	$db->query("update target_period set period_status='close'");
	$db->insert('target_period', { 
    	from_date => $new,
		until_date => $new1,
		period_status => 'open',              
	});

	return "/view/member/list";
}

sub upload_target {
	my ($s, $q, $db, $log) = @_;
	my $upload = $q->upload('file1');
	my $member_id = $q->param('member_id');
	my $member_name = $q->param('member_name');
	$log->warn('upload-target');

        my $pic_data;
        unless ($upload) {
                $log->warn("nggak ada file upload");
		return "/view/member/detail_member";
        }
	my $filehandle;
        open($filehandle, '+>', "/home/software/sds/etc/target_cvs\.csv");
        if ($upload) {
                if (my $size = $upload->size()) {
                        $upload->slurp($pic_data);
                        $log->warn("pic data length: ", length ($pic_data));
                        print $filehandle $pic_data;
		}
		
        }
	close $filehandle;
	
	my $exist;
        open $exist, '<', "/home/software/sds/etc/target_cvs\.csv";
    	unless(scalar $exist) {
        return "/view/member/detail_member";
    }
	# id outlet_name perdana dompul target day
	# 1 amanda-cell 100 200,000 3,000,000 Mon
	my $sum_target=0;
	foreach (<$exist>) {
		my @cols = split /,|;|\r\n|\n|\r|\t/;
		my $jum = scalar(@cols);
		if ($jum != '6') {
		$log->warn("unsupported file");
		next;
		}
		foreach (@cols){
			$_ =~ s/("|')//g;  #delete char like
		}
		my $outlet = $db->query('select outlet_name from outlet where outlet_id=?',$cols[0])->list;	
		unless ($outlet){
			$log->warn("outlet doesn't exist");
			next;
			}
		$log->warn("outlet $cols[1]");
		$log->warn("outlet $outlet");
		if ($outlet ne $cols[1]){
			$log->warn("Warning : nama outlet kok beda?");
			}
		my $o_id = $db->query('select outlet_id from rs_chip where member_id=? and outlet_id=?',$member_id, $cols[0])->list;
		unless ($o_id){
			$log->warn("outlet bukan milik canvasser $member_name");
			next;
			}
		my $dt_id = $db->query('select dt_id from dompul_target where member_id=? and day=? and outlet_id=?',$member_id, $cols[5], $cols[0])->list;
		$log->warn("day",$cols[5]); 
		if ($dt_id){
		$db->query('update dompul_target set qty_target=?, nominal_target=? where member_id=? and ref_type_id=12 and day=? and outlet_id=?',
		$cols[2], $cols[4], $member_id, $cols[5], $cols[0]);
		$log->warn("update qty");
		} else {
		$db->insert('dompul_target',{
			member_id => $member_id,
			ref_type_id => '12',
			qty_target => $cols[2],
			day => $cols[5],
			outlet_id => $cols[0],
			nominal_target => $cols[4],
		});
		$log->warn("insert new");
		}
	$sum_target += $cols[4];
	}
	$log->warn("total-target= $sum_target");
	$db->query('update member set member_target=? where member_id=?',$sum_target, $member_id) if $sum_target > 0;
	$log->warn("done");
	close $exist;
    unlink("/home/software/sds/etc/target_cvs\.csv");

	return "/view/member/list";
}
sub update_additional_user {
    my ($s,$q,$db,$log) = @_;
    my $current = $q->param('current');
    my $username = $q->param('username');
    my $member = $q->param('member_name');
    my $id = $q->param('member_id');
    if($current eq 'ADD'){
        my $c_username = $db->query("select username from additional_user where username=?",$username)->list;
        return "/view/member/additional_list?member_id=$id&member_name=$member&error=NOMOR+SUDAH+TERDAFTAR" if $c_username;
        $db->insert('additional_user',{
            username    => $q->param('username'),
            member_id   => $q->param('member_id'),
            pin         => '1234',
            status      => 'Active',
        });
    }
    if($current eq 'DELETE'){
        my @user_id = $q->param('user_id');
        $db->query("delete from additional_user where add_user_id=?",$_) foreach @user_id;
    }

    return "/view/member/additional_list?member_id=$id&member_name=$member";

}

sub edit_status_additional {
        my ($s, $q, $db, $log) = @_;
        my $name = $q->param('m_name');
        my $m_id = $q->param('m_id');
        my $id = $q->param('id');
    my ($status) = $db->query('select status from additional_user where add_user_id=?', $id)->list;
    my $new_status;
    if ($status eq 'Active') {
        $new_status=2;
    }
    else {
        $new_status=1;
    }
    $log->warn("update additional_user set status=$new_status where add_user_id=$id");
        $s->query('update additional_user set status=? where add_user_id=?',$new_status,$id);
        return "/view/member/additional_list?member_id=$m_id&member_name=$name";
}

1;
