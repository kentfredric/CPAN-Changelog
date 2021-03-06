package CPAN::Changes;
use Moo;
use Sub::Quote qw(qsub);
use Types::Standard qw(ArrayRef HashRef InstanceOf);
use CPAN::Changes::Release;

our $VERSION = '0.500_001';
$VERSION =~ tr/_//d;

my $release_type = (InstanceOf['CPAN::Changes::Release'])->plus_coercions(
  HashRef ,=> qsub q{ CPAN::Changes::Release->new($_[0]) },
);
has _releases => (
  is => 'rw',
  init_arg => 'releases',
  isa => ArrayRef[$release_type],
  coerce => (ArrayRef[$release_type])->coercion,
  default => qsub q{ [] },
);

has preamble => (
  is => 'rw',
  default => '',
);

sub clone {
  my $self = shift;
  return (ref $self)->new(%$self, @_);
}

# backcompat
sub releases {
  my ($self, @args) = @_;
  if (@args > 1 or @args == 1 && ref $args[0] ne 'ARRAY') {
    @args = [ @args ];
  }
  @{ $self->_releases(@args) };
}

sub _numify_version {
    my $version = shift;
    $version = _fix_version($version);
    $version =~ s/_//g;
    if ($version =~ s/^v//i || $version =~ tr/.// > 1) {
        my @parts = split /\./, $version;
        my $n = shift @parts;
        $version = sprintf(join('.', '%s', ('%03s' x @parts)), $n, @parts);
    }
    $version += 0;
    return $version;
}

sub _fix_version {
    my $version = shift;
    return 0 unless defined $version;
    my $v = ($version =~ s/^v//i);
    $version =~ s/[^\d\._].*//;
    $version =~ s/\.[._]+/./;
    $version =~ s/[._]*_[._]*/_/g;
    $version =~ s/\.{2,}/./g;
    $v ||= $version =~ tr/.// > 1;
    $version ||= 0;
    return (($v ? 'v' : '') . $version);
}

sub find_release {
  my ($self, $version) = @_;

  my ($release) = grep { $_->version eq $version } @{ $self->_releases };
  return $release
    if $release;
  $version = _numify_version($version) || return undef;
  ($release) = grep { _numify_version($_->version) == $version } @{ $self->_releases };
  return $release;
}

sub serialize {
  my ($self, %opts) = @_;

  if ($opts{reverse}) {
    $self = $self->clone(releases => [ reverse @{ $self->_releases } ]);
  }

  my $out = $self->preamble || '';
  $out .= "\n\n"
    if $out;

  my $width = $opts{width} || 76;
  my @styles = @{ $opts{styles} || ['', '[]', '-', '*'] };
  my @indents = @{ $opts{indents} || ['', ' ', ''] };

  for my $release (reverse @{$self->_releases}) {
    my $styles = \@styles;
    my $indents = \@indents;
    if (
      grep {
        length($_->text) + length($indents->[0]) + length($styles->[1]) > $width
      }
        @{ $release->entries }
      or
      !grep { $_->has_entries }
        @{ $release->entries }
    ) {
      $styles = [ '', '-', '*' ];
    }
    $out .= "\n"
      unless $out eq '' || $out =~ /\n\n\z/;
    my $sub = $release->serialize(
      indents => $indents,
      styles => $styles,
      width => $width - length $indents->[0],
      group_sort => $opts{group_sort},
    );
    $out .= $sub;
  }
  return $out;
}

require CPAN::Changes::Parser;

# :( i know people use this
our $W3CDTF_REGEX = $CPAN::Changes::Parser::_ISO_8601_DATE;

sub load {
  my ($class, $filename, %args) = @_;
  require CPAN::Changes::Parser;
  CPAN::Changes::Parser->new(%args)->parse_file($filename);
}

sub load_string {
  my ($class, $string, %args) = @_;
  require CPAN::Changes::Parser;
  CPAN::Changes::Parser->new(%args)->parse_string($string);
}

sub add_release {
  my ($self, @releases) = @_;
  push @{ $self->_releases }, map { $release_type->coerce($_) } @releases;
}

sub delete_release {
  my ($self, @versions) = @_;
  my @releases = @{ $self->_releases };
  for my $version (map { _numify_version($_) } @versions) {
    @releases = grep { _numify_version($_->version) != $version } @releases;
  }
  $self->_releases(\@releases);
}

sub release {
  my ($self, $version) = @_;
  $self->find_release($version);
}

sub delete_empty_groups {
  my ($self) = @_;
  for my $release ( @{ $self->_releases } ) {
    $release->delete_empty_groups;
  }
}

1;
__END__

=head1 NAME

CPAN::Changes - Parser for CPAN style change logs

=head1 SYNOPSIS

  use CPAN::Changes;
  my $changes = CPAN::Changes->load('Changes');
  $changes->release('0.01');

=head1 DESCRIPTION

Attemptes to parse CPAN style changelogs as best as possible.

=head1 AUTHOR

haarg - Graham Knop (cpan:HAARG) <haarg@haarg.org>

=head1 CONTRIBUTORS

Brian Cassidy <bricas@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2011-2015 the CPAN::Changes L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<http://dev.perl.org/licenses/>.

=cut
