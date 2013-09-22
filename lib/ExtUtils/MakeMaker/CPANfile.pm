package ExtUtils::MakeMaker::CPANfile;

use strict;
use warnings;
use ExtUtils::MakeMaker ();
use Module::CPANfile;
use version;

our $VERSION = "0.02";

sub import {
  my $class = shift;
  my $orig = \&ExtUtils::MakeMaker::WriteMakefile;
  my $writer = sub {
    my %params = @_;

    if (my $file = eval { Module::CPANfile->load }) {
      my $prereqs = $file->prereqs;

      # Runtime requires => PREREQ_PM
      _merge(
        \%params,
        _get($prereqs, 'runtime', 'requires'),
        'PREREQ_PM',
      );

      # Build requires => BUILD_REQUIRES / PREREQ_PM
      _merge(
         \%params,
         _get($prereqs, 'build', 'requires'),
         _eumm('6.56') ? 'BUILD_REQUIRES' : 'PREREQ_PM',
      );

      # Test requires => TEST_REQUIRES / BUILD_REQUIRES / PREREQ_PM
      _merge(
         \%params,
         _get($prereqs, 'test', 'requires'),
         _eumm('6.63_03') ? 'TEST_REQUIRES' :
         _eumm('6.56') ? 'BUILD_REQUIRES' : 'PREREQ_PM',
      );

      # Configure requires => CONFIGURE_REQUIRES / ignored
      _merge(
         \%params,
         _get($prereqs, 'configure', 'requires'),
         _eumm('6.52') ? 'CONFIGURE_REQUIRES' : undef,
      );

      # Add myself to configure requires (if possible)
      _merge(
         \%params,
         {'ExtUtils::MakeMaker::CPANfile' => 0},
         _eumm('6.52') ? 'CONFIGURE_REQUIRES' : undef,
      );

      # XXX: better to use also META_MERGE when applicable?

      # As a small bonus, remove params that the installed version
      # of EUMM doesn't know, so that we can always write them
      # in Makefile.PL without caring about EUMM version.
      # (EUMM warns if it finds unknown parameters.)
      # As EUMM 6.30 is our prereq, we can safely ignore the keys
      # defined before 6.30.
      {
        last if _eumm('6.66_03');
        if (my $r = delete $params{TEST_REQUIRES}) {
          _merge(\%params, $r, 'BUILD_REQUIRES');
        }
        last if _eumm('6.56');
        if (my $r = delete $params{BUILD_REQUIRES}) {
          _merge(\%params, $r, 'PREREQ_PM');
        }

        last if _eumm('6.52');
        delete $params{CONFIGURE_REQUIRES};

        last if _eumm('6.47_01');
        delete $params{MIN_PERL_VERSION};

        last if _eumm('6.45_01');
        delete $params{META_ADD};
        delete $params{META_MERGE};

        last if _eumm('6.30_01');
        delete $params{LICENSE};
      }
    }

    $orig->(%params);
  };
  {
    no warnings 'redefine';
    *main::WriteMakefile =
    *ExtUtils::MakeMaker::WriteMakefile = $writer;
  }
}

sub _eumm {
  my $version = shift;
  eval { ExtUtils::MakeMaker->VERSION($version) } ? 1 : 0;
}

sub _get {
  my $prereqs = shift;
  eval { $prereqs->requirements_for(@_)->as_string_hash };
}

sub _merge {
  my ($params, $requires, $key) = @_;

  return unless $key;

  for (keys %{$requires || {}}) {
    my $version = _normalize_version($requires->{$_});
    next unless defined $version;

    if (not exists $params->{$key}{$_}) {
      $params->{$key}{$_} = $version;
    } else {
      my $prev = $params->{$key}{$_};
      if (version->parse($prev) < version->parse($version)) {
        $params->{$key}{$_} = $version;
      }
    }
  }
}

sub _normalize_version {
  my $version = shift;

  # shortcuts
  return unless defined $version;
  return $version unless $version =~ /\s/;

  # TODO: better range handling
  $version =~ s/(?:>=|==)\s*//;
  $version =~ s/,.+$//;

  return $version unless $version =~ /\s/;
  return;
}

1;

__END__

=encoding utf-8

=head1 NAME

ExtUtils::MakeMaker::CPANfile - cpanfile support for EUMM

=head1 SYNOPSIS

    # Makefile.PL
    use ExtUtils::MakeMaker::CPANfile;
    
    WriteMakefile(
      NAME => 'Foo::Bar',
      AUTHOR => 'A.U.Thor <author@cpan.org>',
    );
    
    # cpanfile
    requires 'ExtUtils::MakeMaker' => '6.17';
    on test => sub {
      requires 'Test::More' => '0.88';
    };

=head1 DESCRIPTION

ExtUtils::MakeMaker::CPANfile loads C<cpanfile> in your distribution
and modifies parameters for C<WriteMakefile> in your Makefile.PL.
Just use it instead of L<ExtUtils::MakeMaker> (which should be
loaded internally), and prepare C<cpanfile>.

=head1 LIMITATION

As of this writing, complex version ranges are simply ignored.

=head1 LICENSE

Copyright (C) Kenichi Ishigaki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kenichi Ishigaki E<lt>ishigaki@cpan.orgE<gt>

=cut

