package modify::topup;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

use POSIX(qw/strftime/);

my $name = 'topup';

sub edit_topup_request {
	my($s, $q, $db, $log) = @_;
	my $page = $q->param('page');
	my $items = $q->param('items');
	my $limit = ($page-1)*$items;
	# my @array;
	
	my @rs_id = $q->param('rs_id');
	$log->warn("rs id", @rs_id);
	if (scalar(@rs_id)==1) {
		$log->warn('satu');	
		my $stock_ref_id = $db->query('select stock_ref_id from stock_ref inner join topup_request using(stock_ref_id) where admin_id=?',$s->{adm_id});
                while(my($stocks_ref_id)=$stock_ref_id->list){
                        my $qty = $q->param("$rs_id[0]\_$stocks_ref_id");
                        $s->query("replace into topup_request (stock_ref_id,rs_id,qty,admin_id) values(?,?,ifnull(?,'0'),?)",
				   $stocks_ref_id,$rs_id[0],$qty,$s->{adm_id});
                }

		my $rs_number = $db->query("select rs_number from rs_chip where rs_id=?", $rs_id[0])->list;
		return "/view/topup/edit_topup?rs_number=$rs_number";
	}
	else {
		$log->warn("banyak");
		my $result = $db->query('select rs_id from rs_chip limit ?,?', $limit,$items);
		while(my ($rs_id)=$result->list){
			my $stock_ref_id = $db->query('select stock_ref_id from stock_ref inner join topup_request using(stock_ref_id) where admin_id=?',$s->{adm_id});
			while(my($stocks_ref_id)=$stock_ref_id->list){
				my $qty = $q->param("$rs_id\_$stocks_ref_id");
				$s->query("replace into topup_request (stock_ref_id,rs_id,qty,admin_id) values(?,?,ifnull(?,'0'),?)",
					$stocks_ref_id,$rs_id,$qty,$s->{adm_id});
			}
		}
	return "/view/topup/edit_topup?page=$page";
	}
}

sub inject_topup_request {
        my ($s, $q, $db, $log) = @_;
	
	my $page = $q->param('page');
        #my $items = $q->param('items');
        #my $limit = ($page-1)*$items;

        # member id
        my $member_id = $db->query(
                'select member_id from admin where admin_id=?', $s->adm_id,
        )->list
                ||return "/view/topup/edit_topup?error=check+member";
       
	# topup qty
        #my $qty = $q->param("$rs_id\_$ref_id");
		
	#inject
	my @rs_id = $q->param('rs_id');
	
	my $return = "/view/topup/edit_topup?page=$page";

	my $rs = join(',',@rs_id);
	$log->warn('in ', $rs);
	
	$db->begin();
	my $sql = "select stock_ref_id,rs_id,qty from topup_request where rs_id in ($rs) and qty <> 0 and admin_id=$s->{adm_id}";
	$log->warn($sql);
	my $result = $db->query("select stock_ref_id,rs_id,qty from topup_request where rs_id in ($rs) and qty<>0 and admin_id=?",$s->{adm_id});
	
	while (my ($stock_ref_id,$rs_id,$qty) = $result->list) {
		$log->warn("test");
	
		#validation 6 hours interval	
		my ($count) = $db->query("select count(*) from topup where topup_status in ('', 'W', 'P', 'S') and stock_ref_id=? and rs_id=? and topup_qty=? and topup_ts >= (DATE_SUB(now(), INTERVAL 6 hour))", $stock_ref_id, $rs_id, $qty)->list;
		next if ($count);

		my $time = strftime("%Y-%m-%d %H:%M:%S", CORE::localtime(time + 1));
		eval {
			$db->insert('admin_log', {
		      		admin_id => $s->adm_id, page_id => 7, admin_log_ts => $time,
       			});
			my $log_id = $db->last_insert_id(0,0,0,0);
	      	
      		 
			$db->insert('topup', {
              			member_id => $member_id, stock_ref_id => $stock_ref_id,
	              	topup_qty => $qty,       rs_id => $rs_id,
        	        	topup_ts  => \['now()'],
        		});
	      		my $top_id = $db->last_insert_id(0,0,0,0);
	     		$db->insert('topup_web', {topup_id=>$top_id, admin_log_id=>$log_id});
			$db->query('delete from topup_request where rs_id=? and stock_ref_id=? and admin_id=?',$rs_id,$stock_ref_id,$s->{adm_id});
		};
		if ($@) {
			$log->warn($@);
			$db->rollback();
			next;
		}
		$db->commit();
		sleep 1;
	}
	$db->query("delete from topup_request where qty = 0 and admin_id=?",$s->{adm_id});

	if (scalar(@rs_id) == 1) {
		my $rs_number = $db->query("select rs_number from rs_chip where rs_id=?", $rs_id[0])->list;
		$return =  "/view/topup/edit_topup?rs_number=$rs_number";
	}
	
	return $return;
}

sub inject_all_topup_request {
        my ($s, $q, $db, $log) = @_;
	
	my $page = $q->param('page');
        #my $items = $q->param('items');
        #my $limit = ($page-1)*$items;

        # member id
        my $member_id = $db->query(
                'select member_id from admin where admin_id=?', $s->adm_id,
        )->list
                ||return "/view/topup/edit_topup?error=check+member";
       
	# topup qty
        #my $qty = $q->param("$rs_id\_$ref_id");
		
	#inject
	my @rs_id = $q->param('rs_id');
	
	my $return = "/view/topup/edit_topup?page=$page";

	my $rs = join(',',@rs_id);
	$log->warn('in ', $rs);
	
	$db->begin();
	#inject all not check rs per page
	my $sql = "select stock_ref_id,rs_id,qty from topup_request where qty <> 0 and admin_id=$s->{adm_id}";
	$log->warn($sql);
	my $result = $db->query("select stock_ref_id,rs_id,qty from topup_request where qty<>0 and admin_id=?",$s->{adm_id});
	
	while (my ($stock_ref_id,$rs_id,$qty) = $result->list) {
		$log->warn("test");
		
		#validation 6 hours interval
		my ($count) = $db->query("select count(*) from topup where topup_status in ('', 'W', 'P', 'S') and stock_ref_id=? and rs_id=? and topup_qty=? and topup_ts >= (DATE_SUB(now(), INTERVAL 6 hour))", $stock_ref_id, $rs_id, $qty)->list;
                next if ($count);
		
		my $time = strftime("%Y-%m-%d %H:%M:%S", CORE::localtime(time + 1));
		eval {
			$db->insert('admin_log', {
	      			admin_id => $s->adm_id, page_id => 7, admin_log_ts => $time,
	       		});
			my $log_id = $db->last_insert_id(0,0,0,0);
	      	
			$db->insert('topup', {
              			member_id => $member_id, stock_ref_id => $stock_ref_id,
	              	topup_qty => $qty,       rs_id => $rs_id,
        	        	topup_ts  => \['now()'],
        		});
	      		my $top_id = $db->last_insert_id(0,0,0,0);
	     		$db->insert('topup_web', {topup_id=>$top_id, admin_log_id=>$log_id});
			$db->query('delete from topup_request where rs_id=? and stock_ref_id=? and admin_id=?',$rs_id,$stock_ref_id,$s->{adm_id});
		};
		if ($@) {
			$log->warn($@);
			$db->rollback();
			next;
		}
		$db->commit();
		sleep 1;
	}
	$db->query("delete from topup_request where qty = 0 and admin_id=?",$s->{adm_id});

	if (scalar(@rs_id) == 1) {
		my $rs_number = $db->query("select rs_number from rs_chip where rs_id=?", $rs_id[0])->list;
		$return =  "/view/topup/edit_topup?rs_number=$rs_number";
	}
	
	return $return;
}


sub _insert_topup_request {
	my ($s, $log, $db) = @_;

	my $exist;
        open $exist, '<', "/home/software/sds/etc/$name\.csv";
	unless(scalar $exist) {
		return "/view/topup/topup_upload";
	}

	my @stock_ref_id;
	my $row = 0;
	while(<$exist>){
		$row++;
        	my @cols = split /,|;|\r\n|\n|\r|\t/;
		if($row eq 1){
			for (my $j=0;$j<scalar(@cols);$j++) {
				$log->warn("coloms : ", $cols[$j]);
				my $result = $db->query("select stock_ref_id from stock_ref where keyword=?",$cols[$j]);
				while (my $stock_ref_id = $result->list) {
        				push @stock_ref_id, $stock_ref_id;
		        	}
			}
		}else{
			for (my $j=0;$j<scalar(@cols);$j++) {
				$cols[$j] =~ s/"|'//g;		
			}
                
			my $rs_id = $db->query("select rs_id from rs_chip where rs_number =?", $cols[0])->list;
			unless ($rs_id) {
				$log->warn($cols[0],' not existing rs_number');
				next;
			}

			for(my $i=0;$i<scalar(@stock_ref_id);$i++) {
				my $qty = $cols[$i+1];
				my $stock = $stock_ref_id[$i];
				$log->warn("stock ref id : ", $stock);
				my $count = $db->query("select count(*) from topup_request
							where rs_id =? and stock_ref_id = ? and admin_id=?", $rs_id, $stock, $s->{adm_id})->list;
				if ($count) {
					#update
					$db->query('update topup_request set qty=? where rs_id=? and stock_ref_id=? and admin_id=?',$qty, $rs_id, $stock, $s->{adm_id});
					next;
				}
				#insert
				$log->warn('qty', $qty||0);
				eval{
					$db->query('insert into topup_request(qty,rs_id,stock_ref_id,admin_id) values(?,?,?,?)', $qty||0, $rs_id, $stock, $s->{adm_id});
				};
				if($@){
					$log->warn("error insert : ",$@);
				}
			}
		}
	}
        close $exist;
        unlink("/home/software/sds/etc/$name\.csv");

        return "/view/topup/edit_topup";
}

sub topup_upload {
	my ($s, $q, $db, $log) = @_;
	my $upload = $q->upload('file1');
	$log->warn('uplot');

        my $pic_data;
        unless ($upload) {
                $log->warn("nggak ada file upload");
		return "/view/topup/topup_upload";
        }
	my $filehandle;
        open($filehandle, '+>', "/home/software/sds/etc/$name\.csv");
        if ($upload) {
                if (my $size = $upload->size()) {
                        $upload->slurp($pic_data);
                        $log->warn("pic data length: ", length ($pic_data));
                        print $filehandle $pic_data;
		}
		
        }
	close $filehandle;
	my $ret = _insert_topup_request($s, $log, $db);
	return $ret;
}
sub perdana_upload {
	my ($s, $q, $db, $log) = @_;
	my $upload = $q->upload('file1');
	$log->warn('uplot-perd');
	my $today = common::today();

        my $pic_data;
        unless ($upload) {
                $log->warn("nggak ada file upload");
		return "/view/topup/perdana_upload";
        }
	my $filehandle;
        open($filehandle, '+>', "/home/software/sds/etc/perdana\.csv");
        if ($upload) {
                if (my $size = $upload->size()) {
                        $upload->slurp($pic_data);
                        $log->warn("pic data length: ", length ($pic_data));
                        print $filehandle $pic_data;
		}
		
        }
	close $filehandle;
	
	my $exist;
        open $exist, '<', "/home/software/sds/etc/perdana\.csv";
    	unless(scalar $exist) {
        return "/view/topup/perdana_upload";
    }
	foreach (<$exist>) {
		$_ =~ s/(\s*|"|')//g;  #delete char like
		$_ =~ s/^0/62/ if $_ =~ /^0/;
		my ($no)= ($_ =~ /^(\d+)$/);
		unless ($no){
			$log->warn("unsupported file");
			next;
		}
		my $numb = $db->query('select perdana_id from msisdn_perdana where perdana_number=?',$_)->list;
		if ($numb){
			$log->warn("nomor $_ sudah terdaftar");
			next;
		}
		$db->query('insert into msisdn_perdana (perdana_number, ts_perdana) values (?,now())',$_);
			$log->warn("insert nomor $_");

	}
	$log->warn("done");
	close $exist;
    unlink("/home/software/sds/etc/perdana\.csv");

	#return "/view/topup/perdana_upload?sukses";
	return "/view/setting/reg_list?from=$today&until=$today";
}

sub delete_upload {
        my ($s, $q, $db, $log) = @_;

	#delete from topup_request where admin_id=17;
	$log->warn("delete topup_request for admin_id = ".$s->{adm_id});
	$db->begin();
	#delete not used upload
	$db->query("delete from topup_request where admin_id=?", $s->{adm_id});
	$db->commit();

        return "/view/topup/edit_topup";
}
