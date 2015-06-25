package OBS::Package::RevisionList;

use Moose;
use Path::Class::Dir;
use Path::Class::File;
use feature 'say';
use Data::Dumper;

use OBS::Package::Revision;

has 'package' => (isa=>'Str',is=>'ro');
has 'project' => (isa=>'Str',is=>'ro');
has 'path_to_obs' => (isa=>'Str',is=>'ro');
has '_rev_list' => (
   	isa=>'ArrayRef',
        #isa     => 'ArrayRef[Str]',
	is=>'rw',
        traits  => ['Array'],
        default => sub { [] },
        handles => {
            all_revisions    => 'elements',
            map_revisions    => 'map',
            #filter_options => 'grep',
            #find_option    => 'first',
            #get_option     => 'get',
            #join_options   => 'join',
            count_revisions  => 'count',
            has_revisions    => 'count',
            has_no_revisions => 'is_empty',
            add_revision     => 'push',
	    shift_revisions  => 'shift',
            #sorted_options => 'sort',
        },
    );


sub read_from_file {
	my $self = shift;

	my $infile = Path::Class::File->new($self->path_to_obs,'projects',$self->project.".pkg",$self->package.".rev");

	foreach my $line ( $infile->slurp ) {
		chomp $line;
		my @data = split('\|',$line);
		my $rev = OBS::Package::Revision->new(
			project			=> $self->project,
			package			=> $self->package,
			path_to_obs		=> $self->path_to_obs,

			id			=> $data[0],
			id2			=> $data[1],
			md5sum			=> $data[2],
			version			=> $data[3],
			commit_timestamp	=> $data[4],
			committer		=> $data[5],
			commit_comment		=> $data[6] || '',
			
		);
		$self->add_revision($rev);
	}
}

sub to_string {
	my $self = shift;
	my $string = '';
	$self->map_revisions(sub { $string .= $_->to_string() . "\n" });

	return $string
	
}

sub cleanup_revisions {
	my $self = shift;
	my @tmp_list = ();
	my $index=1;
	if (! $self->has_revisions) {
		$self->read_from_file();
	}
	while ( my $rev = $self->shift_revisions() ) { 
		if ( $rev->verify_files() ) {
			$rev->id($index);
			$rev->id2($index);
			push(@tmp_list,$rev);
			$index++;
		} else {
			$rev->remove_files_with_broken_child();
		}
	}
	$self->_rev_list(\@tmp_list);
	$self->write_to_file();

	return 1;
}

sub write_to_file {
	my $self = shift;

	my $outfile = Path::Class::File->new($self->path_to_obs,'projects',$self->project.".pkg",$self->package.".rev");

	$outfile->spew($self->to_string());
}

1;
