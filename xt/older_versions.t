use strict;
use warnings;
use File::Temp;
use Test::More;

plan skip_all => 'requires WorePAN' unless eval { require WorePAN; WorePAN->VERSION(0.04); 1 };

my @targets = qw(
    MSCHWERN/ExtUtils-MakeMaker-6.17.tar.gz
    MSCHWERN/ExtUtils-MakeMaker-6.31.tar.gz
    MSCHWERN/ExtUtils-MakeMaker-6.48.tar.gz
    MSCHWERN/ExtUtils-MakeMaker-6.52.tar.gz
    MSCHWERN/ExtUtils-MakeMaker-6.54.tar.gz
    MSCHWERN/ExtUtils-MakeMaker-6.56.tar.gz
    MSTROUT/ExtUtils-MakeMaker-6.59.tar.gz
    MSCHWERN/ExtUtils-MakeMaker-6.63_03.tar.gz
    BINGOS/ExtUtils-MakeMaker-6.76.tar.gz
);

for my $dist (@targets) {
    my $worepan = WorePAN->new(
        root => File::Temp::tempdir(CLEANUP => 1),
        files => [$dist],
        use_backpan => 1,
        no_network => 0,
        no_indices => 1,
        cleanup => 1,
    );
    $worepan->walk(callback => sub {
        my $distdir = shift;
        my $eumm = `perl -I $distdir/lib -MExtUtils::MakeMaker -e 1 2>&1`;
        if ($eumm =~ /syntax error/) {
          note "$dist is skipped because of loading errors";
          return;
        }
        my $res = `prove -I $distdir/lib -lvw t/01_basic.t`;
        unlike $res => qr/not ok/;
        note $res;
    }, developer_releases => 1,);
}

done_testing;
