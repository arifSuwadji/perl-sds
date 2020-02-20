package modify::rs_chip;
use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

sub add_member_id {
	my ($s,$q,$db,$log) = @_;
        my $rs_number = $q->param('rs_number');
        my $member_id = $q->param('member_id');
        my $member_name = $q->param('member_name');
	$log->warn("member_id=$member_id");
	my ($rs_id) = $db->query('select rs_id from rs_chip where rs_number=? and member_id is null', $rs_number)->list;
	$db->query('update rs_chip set member_id=? where rs_number=?', $member_id, $rs_number) if defined($rs_id);
        return "/view/member/detail_member?id=$member_id&member_name=$member_name";
}

sub delete_member_id {
        my ($s, $q, $db, $log) = @_;
        my @rs_id = $q->param('rs_id');
        my $member_id = $q->param('member_id');
        my $member_name = $q->param('member_name');
	foreach (@rs_id) {
	        $s->query('update rs_chip set member_id=null where rs_id=?',$_);
        }
	return "/view/member/detail_member?id=$member_id&member_name=$member_name";
}

1;
