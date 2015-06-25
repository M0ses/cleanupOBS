package OBS::Package::Revision;

use Moose;
use Path::Class qw/file/;

has project => (isa=>'Str',is=>'rw');
has package => (isa=>'Str',is=>'rw');
has path_to_obs => (isa=>'Str',is=>'rw');

has id => (isa=>'Int',is=>'rw');
has id2 => (isa=>'Int',is=>'rw');
has md5sum => (isa=>'Str',is=>'rw');
has version => (isa=>'Str',is=>'rw');
has commit_timestamp => (isa=>'Int',is=>'rw');
has committer => (isa=>'Str',is=>'rw');
has commit_comment => (isa=>'Str',is=>'rw');

has file_list =>( 
        isa=>'ArrayRef',
        #isa     => 'ArrayRef[Str]',
        is=>'rw',
        traits  => ['Array'],
        is      => 'ro',
        default => sub { [] },
        handles => {
            all_files    => 'elements',
            map_files    => 'map',
            #filter_options => 'grep',
            #find_option    => 'first',
            get_file => 'get',
            #join_options   => 'join',
            count_files  => 'count',
            has_files    => 'count',
            has_no_files => 'is_empty',
            add_file     => 'push',
            #sorted_options => 'sort',
        },
    );

has files_to_delete =>( 
        isa=>'ArrayRef',
        #isa     => 'ArrayRef[Str]',
        is=>'rw',
        traits  => ['Array'],
        is      => 'ro',
        default => sub { [] },
        handles => {
            all_files_to_delete    => 'elements',
            map_files_to_delete    => 'map',
            #filter_options => 'grep',
            #find_option    => 'first',
            #join_options   => 'join',
            count_files_to_delete  => 'count',
            has_files_to_delete    => 'count',
            has_no_files_to_delete => 'is_empty',
            add_file_to_delete     => 'push',
            #sorted_options => 'sort',
        },
    );

sub to_string {
	my $self=shift;

	return join('|',(map { $self->$_() } qw/id id2 md5sum version commit_timestamp committer commit_comment/));
}

sub locate_files {
	my $self = shift;
	
	my $start_file = file($self->path_to_obs,'trees',$self->project,$self->package,$self->md5sum."-MD5SUMS");

	if ( ! -e $start_file ) {
		return 0;
	}
	# important to be first element in files array;
	my $file_info = {
		file		=> $start_file,
		parent		=> 0,
		found		=> 0,
		broken_child	=> 0
	};
	$self->add_file($file_info);

	foreach my $line ($start_file->slurp) {
		my ($md5,$file) = split(/\s+/,$line);
		if ( $file eq '/SERVICE') {
			$self->_read_service_file($md5,$file_info);
		} else {
			$self->add_file({
				file		=> file($self->path_to_obs,'sources',$self->package,"$md5-$file"),
				parent		=> $start_file,
				found		=> 0,
				broken_child	=> 0
			});
		}
	}

	
}

sub _read_service_file {
	my $self 		= shift;
	my $md5_in 		= shift;
	my $parent_file_info	= shift;
	my $start_file = file($self->path_to_obs,'trees',$self->project,$self->package,$md5_in."-MD5SUMS");
	my $parent = $parent_file_info->{file};

	my $file_info = {
		file		=> $start_file,
		parent		=> $parent_file_info->{file},
		found		=> ( -e $start_file ),
		broken_child	=> 0,
	};

	if ( ! $file_info->{found} ) {
		$parent_file_info->{broken_child} = 1;
		return 0;
	}

	$self->add_file($file_info);

	foreach my $line ($start_file->slurp) {
		my ($md5,$file) = split(/\s+/,$line);
		if ( $file eq '/LSERVICE') {
			if ( $parent->stringify !~ /\/$md5-MD5SUMS/ ) {
				printf("Missmatch between LSERVICE (%s) and parent file '%s'!",$md5,$parent->basename);
				next
			}
		} else {
			# tf = temporary file	
			my $tf 		= file($self->path_to_obs,'sources',$self->package,"$md5-$file");
			my $fifs 	= 0;
			
			if ( -e $tf ) {
				$fifs = 1;
			} else {
				$parent_file_info->{broken_child} = 1;
				$file_info->{broken_child} = 1;
			}
			my $struct = {
				file		=> $tf,
				parent		=> $start_file,
				found		=> $fifs,
				broken_child	=> 0
			};
			$self->add_file($struct);
		}
	}


	return 1;
}

sub verify_files {
	my $self = shift;
	my $rc = 1;
	if (! $self->has_files ) {
		$self->locate_files();
	}

	return 0 if (! $self->has_files );

	$self->map_files(sub{
		my $file = $_;
		if ( $_->{broken_child} ) {
			$rc = 0;
			$self->add_file_to_delete($_);
		}

		$file->{found} = ( -e $file->{file} ) ? 1 : 0;

		$rc = 0 if ( ! $file->{found} ); 
	});
	return $rc; 
}

sub remove_files_with_broken_child {
	my $self = shift;

	$self->map_files_to_delete(sub {
		$_->{file}->remove();
	});

}

1;
