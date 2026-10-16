
# Tests for bacds::Scheduler::Model::FormQueue, which reviews queued
# "Add someone to your membership" requests, with a fake CiviCRM client,
# and for the bin/ scripts that use it.

use 5.32.1;
use warnings;

use Test::Exception;
use Test::More;

use bacds::Scheduler::Model::FormQueue;

# A pending request from holder 16 to add Robin as their spouse, shaped
# like the AfformSubmission data CiviCRM 6.19 stores
sub pending_submission {
    my (%args) = @_;
    return {
        id              => $args{id} // 19,
        submitter_id    => 16,
        submitter_name  => 'Pat Holder',
        submission_date => '2026-10-09 18:47:08',
        status          => 'Pending',
        data            => {
            Individual1 => [{
                fields => { id => 16, first_name => 'Pat', last_name => 'Holder' },
            }],
            Individual2 => [{
                fields => { first_name => 'Robin', last_name => 'Holder' },
                joins  => { Email => [{ email => $args{email} // 'robin@example.com',
                                        location_type_id => 3 }] },
            }],
            Relationship1 => [{ fields => { relationship_type_id => 2 } }],
        },
    };
}

# How processing changes it: ids saved next to "fields"
sub processed_submission {
    my (%args) = @_;
    my $submission = pending_submission();
    $submission->{status} = 'Processed';
    $submission->{data}{Individual1}[0]{id} = $args{holder_id} // 16;
    $submission->{data}{Individual2}[0]{id} = $args{new_id} if defined $args{new_id};
    return $submission;
}

test_pending_and_format();
test_get();
test_approve_ok();
test_approve_problems();
test_approve_wrong_holder();
test_approve_no_inherited_membership();
test_approve_not_pending();
test_reject();
test_scripts_compile();

done_testing;

sub test_pending_and_format {
    my $civi  = FakeCivi->new(submissions => [ pending_submission() ]);
    my $queue = bacds::Scheduler::Model::FormQueue->new(civi => $civi);

    my $pending = $queue->pending;
    is scalar @$pending, 1, 'one pending request';
    is_deeply $civi->{calls}[0],
        ['get_form_submissions', 'afformAddSomeoneToYourMembership', status => 'Pending'],
        'asks CiviCRM for pending submissions to the default form';

    my $request = $pending->[0];
    is $request->{holder_name},    'Pat Holder',        'holder name';
    is $request->{new_first_name}, 'Robin',             'new first name';
    is $request->{new_email},      'robin@example.com', 'new email from the Email block';
    is $request->{relationship},   'Spouse of',         'relationship label';

    is $queue->format_request($request), <<'EOT', 'formatted for the email';
Request #19, submitted 2026-10-09 18:47:08 (Pending)
  From: Pat Holder (contact 16)
  Add:  Robin Holder <robin@example.com>
  As:   Spouse of Pat Holder
EOT

    my $no_email = bacds::Scheduler::Model::FormQueue->new(
        civi => FakeCivi->new(submissions => [ pending_submission(email => '') ]),
    )->pending->[0];
    like $queue->format_request($no_email), qr{Add:  Robin Holder\n},
        'no email shown when none was given';
}

sub test_get {
    my $queue = bacds::Scheduler::Model::FormQueue->new(
        civi => FakeCivi->new(submissions => []),
    );
    throws_ok { $queue->get(99) } qr{There's no submission 99},
        'dies for an unknown submission';
    throws_ok { $queue->get('19; drop') } qr{must be a number},
        'dies for a non-numeric id';
}

sub test_approve_ok {
    my $civi = FakeCivi->new(
        submissions      => [ pending_submission() ],
        after_process    => processed_submission(new_id => 750),
        relationships    => [{ id => 900, relationship_type_id => 2, is_active => 1 }],
        inherited        => { id => 870, type_name => 'Family', end_date => '2027-03-31' },
    );
    my $queue  = bacds::Scheduler::Model::FormQueue->new(civi => $civi);
    my $report = $queue->approve(19);

    ok $report->{ok}, 'approve: ok';
    is $report->{new_contact_id}, 750, 'approve: new contact id';
    is_deeply $report->{problems}, [], 'approve: no problems';
    ok((grep { /process_form_submission/ } map { $_->[0] } @{ $civi->{calls} }),
        'approve: processed the submission');
    is_deeply((grep { $_->[0] eq 'relationships_between' } @{ $civi->{calls} })[0],
        ['relationships_between', 750, 16],
        'approve: checks for a relationship from the new person to the holder');
    like join("\n", @{ $report->{notes} }), qr{Relationship 900: contact 750 is Spouse of Pat Holder},
        'approve: notes the relationship';
    like join("\n", @{ $report->{notes} }), qr{inherited Family membership \(#870},
        'approve: notes the inherited membership';
}

sub test_approve_problems {
    # Processing left it pending and created nobody
    my $queue = bacds::Scheduler::Model::FormQueue->new(civi => FakeCivi->new(
        submissions   => [ pending_submission() ],
        after_process => pending_submission(),
    ));
    my $report = $queue->approve(19);
    ok !$report->{ok}, 'nothing saved: not ok';
    like join("\n", @{ $report->{problems} }), qr{still Pending after processing},
        'nothing saved: still pending';
    like join("\n", @{ $report->{problems} }), qr{didn't create or match a contact},
        'nothing saved: no contact';

    # Contact created, but no relationship of the requested type, and no
    # inherited membership (a note, not a problem)
    $queue = bacds::Scheduler::Model::FormQueue->new(civi => FakeCivi->new(
        submissions   => [ pending_submission() ],
        after_process => processed_submission(new_id => 750),
        relationships => [
            { id => 901, relationship_type_id => 1, is_active => 1 },  # wrong type
            { id => 902, relationship_type_id => 2, is_active => 0 },  # inactive
        ],
    ));
    $report = $queue->approve(19);
    ok !$report->{ok}, 'no relationship: not ok';
    like join("\n", @{ $report->{problems} }),
        qr{no active "Spouse of" relationship from contact 750 to Pat Holder \(contact 16\)},
        'no relationship: says which one is missing';
}

sub test_approve_no_inherited_membership {
    # Everything worked except the inherited membership; why not?
    my $approve = sub {
        my ($capacities) = @_;
        my $queue = bacds::Scheduler::Model::FormQueue->new(civi => FakeCivi->new(
            submissions   => [ pending_submission() ],
            after_process => processed_submission(new_id => 987),
            relationships => [{ id => 128, relationship_type_id => 2, is_active => 1 }],
            capacities    => $capacities,
        ));
        my $report = $queue->approve(19);
        return ($report->{ok}, join "\n", @{ $report->{problems} });
    };

    # What happened to request #19: an old membership still limited to 2
    my ($ok, $problems) = $approve->([{
        id => 867, type_name => 'Family', passes_to_related => 1,
        max_related => 2, inherited_count => 2,
    }]);
    ok !$ok, 'membership at its own limit: not ok';
    like $problems,
        qr{Contact 987 didn't get an inherited membership from Pat Holder: Pat Holder's Family membership \(#867\) already passes to 2 people, its limit of 2},
        'membership at its own limit: explained';
    like $problems, qr{Raise that membership's max_related}, '... with what to do';

    ($ok, $problems) = $approve->([]);
    like $problems, qr{Pat Holder has no current membership of their own}, 'no current membership';

    ($ok, $problems) = $approve->([{
        id => 50, type_name => 'Individual', passes_to_related => 0,
        max_related => undef, inherited_count => 0,
    }]);
    like $problems, qr{Pat Holder's Individual membership \(#50\) doesn't pass to related contacts},
        'membership type not shared';

    ($ok, $problems) = $approve->([{
        id => 867, type_name => 'Family', passes_to_related => 1,
        max_related => undef, inherited_count => 2,
    }]);
    ok !$ok, 'room left but nothing inherited: not ok';
    like $problems, qr{CiviCRM should have created one from #867 but didn't},
        'room left but nothing inherited: says so';
}

sub test_approve_wrong_holder {
    # What CiviCRM before 6.19 did: the holder resolved to whoever processed it
    my $queue = bacds::Scheduler::Model::FormQueue->new(civi => FakeCivi->new(
        submissions   => [ pending_submission() ],
        after_process => processed_submission(new_id => 750, holder_id => 3),
        relationships => [],
    ));
    my $report = $queue->approve(19);
    ok !$report->{ok}, 'wrong holder: not ok';
    like join("\n", @{ $report->{problems} }),
        qr{holder resolved to contact 3, not contact 16 who submitted},
        'wrong holder: reported';
}

sub test_approve_not_pending {
    my $civi  = FakeCivi->new(submissions => [ processed_submission(new_id => 750) ]);
    my $queue = bacds::Scheduler::Model::FormQueue->new(civi => $civi);
    throws_ok { $queue->approve(19) } qr{Request #19 is Processed, not Pending},
        'approve dies unless pending';
    ok !(grep { $_->[0] eq 'process_form_submission' } @{ $civi->{calls} }),
        'and does not process it';
}

sub test_reject {
    my $civi  = FakeCivi->new(submissions => [ pending_submission() ]);
    my $queue = bacds::Scheduler::Model::FormQueue->new(civi => $civi);
    lives_ok { $queue->reject(19) } 'reject a pending request';
    is_deeply $civi->{calls}[-1], ['reject_form_submission', 19], 'asked CiviCRM to reject it';

    $civi  = FakeCivi->new(submissions => [ pending_submission() ], reject_count => 0);
    $queue = bacds::Scheduler::Model::FormQueue->new(civi => $civi);
    throws_ok { $queue->reject(19) } qr{CiviCRM didn't reject request #19},
        'dies if CiviCRM rejected nothing';

    $civi  = FakeCivi->new(submissions => [ processed_submission(new_id => 750) ]);
    $queue = bacds::Scheduler::Model::FormQueue->new(civi => $civi);
    throws_ok { $queue->reject(19) } qr{is Processed, not Pending}, 'reject dies unless pending';
}

sub test_scripts_compile {
    for my $script (qw(bin/civicrm-form-queue.pl bin/civicrm-check-form-queue.pl)) {
        my $out = `$^X -CA -Ilib -c $script 2>&1`;
        like $out, qr{syntax OK}, "$script compiles";
    }
}

# A stand-in for bacds::Scheduler::CiviCRM that records calls. After
# process_form_submission, get_form_submissions returns after_process.
package FakeCivi;

sub new {
    my ($class, %args) = @_;
    return bless { reject_count => 1, %args, calls => [] }, $class;
}

sub get_form_submissions {
    my ($self, $form, %filter) = @_;
    push @{ $self->{calls} }, ['get_form_submissions', $form, %filter];
    my @submissions = $self->{processed}
        ? ($self->{after_process})
        : @{ $self->{submissions} };
    @submissions = grep { $_->{status} eq $filter{status} } @submissions
        if defined $filter{status};
    @submissions = grep { $_->{id} == $filter{id} } @submissions
        if defined $filter{id};
    return [ @submissions ];
}

sub process_form_submission {
    my ($self, $form, $id) = @_;
    push @{ $self->{calls} }, ['process_form_submission', $form, $id];
    $self->{processed} = 1;
    return {};
}

sub reject_form_submission {
    my ($self, $id) = @_;
    push @{ $self->{calls} }, ['reject_form_submission', $id];
    return $self->{reject_count};
}

sub relationship_type_labels { return { 1 => 'Child of', 2 => 'Spouse of' } }

sub relationships_between {
    my ($self, $a, $b) = @_;
    push @{ $self->{calls} }, ['relationships_between', $a, $b];
    return $self->{relationships} // [];
}

sub inherited_membership_from { return $_[0]{inherited} }

sub membership_capacities { return $_[0]{capacities} // [] }
