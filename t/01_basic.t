use strict;
use warnings;
use Test::More;
use File::Path;
use FindBin;
use Cwd ();

my $cwd = Cwd::cwd();
my $testdir = "$FindBin::Bin/tmp";
eval {
  mkpath $testdir;
  chdir $testdir;
  { # generate Makefile.PL
    open my $fh, '>', "$testdir/Makefile.PL" or die;
    print $fh <<'MK_END';
      use strict;
      use warnings;
      use ExtUtils::MakeMaker;
      use ExtUtils::MakeMaker::CPANfile;
      print "# EUMM version: ", $ExtUtils::MakeMaker::VERSION, "\n";
      WriteMakefile(
        NAME => 'Test::EUMM::CPANfile',
        AUTHOR => 'Test',
      );
MK_END
  }
  { # generate cpanfile
    open my $fh, '>', "$testdir/cpanfile" or die;
    print $fh <<'CF_END';
      requires 'ExtUtils::MakeMaker', 6.66;

      on configure => sub {
        requires 'ExtUtils::MakeMaker', 6.30;
      };

      on build => sub {
        requires 'Test::More', 0.47;
      };

      on test => sub {
        requires 'Test::More', 0.88;
      };
CF_END
  }
  { # generate .pm file
    open my $fh, '>', "$testdir/CPANfile.pm" or die;
    print $fh "package #\n", "Test::EUMM::CPANfile;\n", "1;\n";
  }
};
plan skip_all => "failed to set up a test distribution" if $@;

ok !system("$^X Makefile.PL"), "ran Makefile.PL";
ok -f "Makefile", "generated Makefile";

my $makefile = do { local $/; open my $fh, '<', "Makefile"; <$fh> };
ok $makefile && $makefile =~ /(?:_REQUIRES|PREREQ_PM)\s*=>\s*{\s*[^{]*ExtUtils::MakeMaker\s*=>\s*q\[/, "EUMM is listed as some kind of prereqs";
ok $makefile && $makefile =~ /(?:_REQUIRES|PREREQ_PM)\s*=>\s*{\s*[^{]*Test::More\s*=>\s*q\[/, "Test::More is listed as some kind of prereqs";

done_testing;

END {
  if ($cwd && $cwd ne Cwd::cwd()) {
    chdir $cwd;
    eval { rmtree $testdir } if $testdir && -d $testdir;
  }
}
