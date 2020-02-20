package modify::setting;
use strict;
use common;
use warnings FATAL => 'all';
no warnings 'redefine';

sub reg_command {
	my ($s,$q,$db,$log) = @_;
	my $current = $q->param('current');
    if($current eq 'ADD'){
        $db->insert('perdana_cmd',{
            cmd_name     => $s->param('filename'),
            type         => $s->param('type'),
            command      => $s->param('form_set'),
            receiver     => $s->param('receiver'),
        });
    }

    if($current eq 'UPDATE'){
        my @take = $q->param('take');
                    $db->update('perdana_cmd',
                {
                type         => $s->param("upd_type$_"),
                command      => $s->param("upd_form$_"),
                receiver     => $s->param("upd_receiver$_"),
                },
                { cmd_id   => $_ }
            ) foreach @take ;
    }
	if($current eq 'DELETE'){
        my @take = $q->param('take');
        $db->query("delete from perdana_cmd where cmd_id=?",$_) foreach @take;
    }

    if($current eq 'ADD_MODEM'){
        $db->insert('modem',{
            modem_name => $q->param('modemname'),
            pin => $q->param('pin'),
        });
    }

    if($current eq 'UPD_MODEM'){
        my @chkmodem = $q->param('chkmodem');
        $db->update('modem',{ 
			modem_name => $q->param("chmodem$_"),
			pin => $q->param("chpin$_"),
		},
		{ modem_id => $_ }) foreach @chkmodem;
    }

    return "/view/setting/reg_command";
	
}

sub modem {
    my ($s, $q, $db, $log) = @_;

    $db->update('modem',
        { status => $q->param('status') },
        { modem_id => $q->param('modem_id')}
    );

    return "/view/setting/reg_command";
}
sub change_status_perdana {
    my ($s, $q, $db, $log) = @_;
    my $perdana_id = $q->param('perdana_id');
    my $from = common::today();
    my $until = common::today();
    my $status;
    if ($q->param('status') eq 'Active') {
        $status = 2;
    } else {
        $status = 1;
    }

    $db->query('update msisdn_perdana set status = ? where perdana_id = ?', $status, $perdana_id);
    return "/view/setting/reg_list?from=$from&until=$until";
}
	
1;
