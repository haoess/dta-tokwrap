#!/usr/bin/perl -w

use lib ('.');
use DTA::TokWrap;
use DTA::TokWrap::Utils qw(:si);
use File::Basename qw(basename);
use IO::File;

use Getopt::Long (':config' => 'no_ignore_case');
use Pod::Usage;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------

##-- general
our $prog = basename($0);
our ($help,$man,$version);
our $verbose = 0;      ##-- verbosity

##-- DTA::TokWrap options
my %bx0opts = DTA::TokWrap::Processor::mkbx0->defaults();
our %twopts = (
	       inplacePrograms=>1,
	       keeptmp => 0,
	       procOpts => {
			    #traceLevel => 'trace',
			    hint_sb_xpaths => $bx0opts{hint_sb_xpaths},
			    hint_wb_xpaths => $bx0opts{hint_wb_xpaths},
			   },
	      );
our %docopts = (
		##-- Document class options
		class => 'DTA::TokWrap::Document',
		#class => 'DTA::TokWrap::Document::Maker',

		##-- DTA::TokWrap::Document options
		#traceOpen => 'trace',
		#traceClose => 'trace',
		#traceLoad   => 'trace',
		#traceSave   => 'trace',
		format => 1,

		##-- DTA::TokWrap::Document::Maker options
		#traceMake => 'trace',
		#traceGen  => 'trace',
		#genDummy => 0,
		#force => 0,  ##-- propagated from DTA::TokWrap $doc->{tw}
	       );

##-- Logging options
our $logConfFile = undef;
our ($logConf);            ##-- default log configuration string; see below
our $logToStderr = 1;      ##-- log to stderr?
our $logFile     = undef;  ##-- log to file?
our $logProfile  = 'info'; ##-- log-level for profiling information?

##-- make/generate options
our $makeKeyAct = 'make';   ##-- one of 'make', 'gen'
our @targets = qw();
our @defaultTargets = qw(all);

##-- debugging options
our $dump_xsl_prefix = undef;
our $traceLevel = 'trace'; ##-- trace level for '-trace' options
our @traceOptions = (
		     {opt=>'traceOpen',ref=>\$docopts{traceOpen},vlevel=>1},
		     {opt=>'traceClose',ref=>\$docopts{traceClose},vlevel=>3},
		     {opt=>'traceLoad',ref=>\$docopts{traceLoad},vlevel=>2},
		     {opt=>'traceSave',ref=>\$docopts{traceSave},vlevel=>2},
		     {opt=>'traceMake',ref=>\$docopts{traceMake},vlevel=>2},
		     {opt=>'traceGen',ref=>\$docopts{traceGen},vlevel=>3},
		     {opt=>'traceProc',ref=>\$twopts{procOpts}{traceLevel},vlevel=>3},
		     {opt=>'traceRun', ref=>\$DTA::TokWrap::Utils::TRACE_RUNCMD,vlevel=>3},
		    );
our $verbose_max = 255;

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------

## undef = setVerboseTrace($bool)
## undef = setVerboseTrace($bool,$verbose)
##  + set trace options by verbosity level
sub setVerboseTrace {
  my $_verbose = defined($_[1]) ? $_[1] : $verbose;
  ${$_->{ref}} = ($_[0] ? $traceLevel : undef) foreach (grep {$_verbose>=$_->{vlevel}} @traceOptions);
}

GetOptions(
	   ##-- General
	   'help|h' => \$help,
	   'man' => \$man,
	   'verbose|v=i' => sub { $verbose=$_[1]; setVerboseTrace(1); },
	   'verbion|V' => \$version,

	   ##-- pseudo-make
	   'make|m' => sub { $docopts{class}='DTA::TokWrap::Document::Maker'; $makeKeyAct='make'; },
	   'nomake|M' => sub { $docopts{class}='DTA::TokWrap::Document'; },
	   'remake|r!' => sub { $docopts{class}='DTA::TokWrap::Document::Maker'; $makeKeyAct='remake'; },
	   'targets|target|t=s' => \@targets,
	   'force-target|ft=s' => sub { push(@{$twopts{force}},$_[1]) },
	   'force|f' => sub { push(@{$twopts{force}},'all') },
	   'noforce|nof' => sub { $twopts{force} = [] },

	   ##-- DTA::TokWrap::Processor options
	   'inplacePrograms|inplace|i!' => \$twopts{inplacePrograms},
	   'processor-option|procopt|po=s%' => $twopts{procOpts},
	   'sentence-break-xpath|sb-xpath|sbx|sb=s@' => $twopts{procOpts}{hint_sb_xpaths},
	   'word-break-xpath|wb-xpath|wbx|wb=s@' => $twopts{procOpts}{hint_wb_xpaths},

	   ##-- DTA::TokWrap options: I/O
	   'outdir|od|d=s' => \$twopts{outdir},
	   'tmpdir|tmp|T=s' => \$twopts{tmpdir},
	   'keeptmp|keep|k!' => \$twopts{keeptmp},
	   'format-xml|format|fmt|pretty-xml|pretty|fx|px:i'  => sub { $docopts{format} = $_[1]||1; },
	   'noformat-xml|noformat|nofmt|nopretty-xml|nopretty|nofx|nopx'  => sub { $docopts{format} = 0; },

	   ##-- Log options
	   'log-config|logconfig|logconf|log-rc|logrc|lc=s' => \$logConfFile,
	   'log-level|loglevel|ll=s' => \$DTA::TokWrap::Logger::DEFAULT_LOGLEVEL,
	   'log-file|logfile|lf=s' => \$logFile,
	   'log-stderr|stderr|le!' => \$logToStderr,
	   'log-profile|profile|p!' => sub { $logProfile=$_[1] ? 'info' : undef; },
	   'silent|quiet|q' => sub {
	     $verbose=0;
	     setVerboseTrace(0,$verbose_max);
	     $DTA::TokWrap::Logger::DEFAULT_LOGLEVEL='FATAL';
	   },

	   ##-- Debugging options
	   (map {
	     my ($opt,$ref) = @$_{qw(opt ref)};
	     ("${opt}" => sub { $$ref = $traceLevel },
	      "${opt}Level=s" => sub { $$ref = $_[1] },
	      (map { ("no$_" => sub { $$ref=undef }) } split(/\|/, $opt))
	     )
	   } @traceOptions),
	   "traceLevel|trace-level=s" => \$traceLevel,
	   "trace!" => sub { setVerboseTrace($_[1]); },
	   "traceAll|trace-all!" => sub { setVerboseTrace($_[1],$verbose_max); },
	   "dummy|no-act|n!" => \$docopts{dummy},

	   'dump-xsl-stylesheets|dump-xsl:s' => \$dump_xsl_prefix,
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({-exitval=>0, -verbose=>1}) if ($man);
pod2usage({
	   -message => 'No XML source file(s) specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 1);

if ($version) {
  print "$prog: DTA::TokWrap v$DTA::TokWrap::VERSION\n";
  exit(0);
}


##==============================================================================
## Subs
##==============================================================================

##--------------------------------------------------------------
## Subs: Messaging

sub vmsg {
  my ($vlevel,@msg) = @_;
  if ($verbose >= $vlevel) {
    print STDERR @msg;
  }
}

sub vmsg1 {
  vmsg($_[0],"$prog: ", @_[1..$#_], "\n");
}


##--------------------------------------------------------------
## Subs: File processing

## $bool = processFile($argvFile)
##  + process a single file
sub processFile {
  my $f = shift;
  my $rc = 1;
  eval {
    $rc &&= ($doc = $tw->open($f,%docopts));
    foreach $target (@targets) {
      last if (!$rc);
      $rc &&= defined($makeKeySub->($doc,$target));
    }
    $rc &&= $doc->close();
  };
  return $rc;
}


##==============================================================================
## MAIN
##==============================================================================

##-- init logger
if (defined($logConfFile)) {
  DTA::TokWrap->logInit($logConfFile);
} else {
  $logConf ="
##-- Loggers
log4perl.oneMessagePerAppender = 1     ##-- suppress duplicate messages to the same appender
log4perl.rootLogger     = WARN, AppStderr
log4perl.logger.DTA.TokWrap = ". join(', ',
				      '__DTA_TOKWRAP_DEFAULT_LOGLEVEL__',
				      ($logToStderr ? 'AppStderr' : qw()),
				      ($logFile     ? 'AppFile'   : qw()),
				     ) . "

##-- Appenders: Utilities
log4perl.PatternLayout.cspec.G = sub { return '$prog'; }

##-- Appender: AppStderr
log4perl.appender.AppStderr = Log::Log4perl::Appender::Screen
log4perl.appender.AppStderr.stderr = 1
log4perl.appender.AppStderr.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.AppStderr.layout.ConversionPattern = %G[%P] %p: %c: %m%n

##-- Appender: AppFile
log4perl.appender.AppFile = Log::Log4perl::Appender::File
log4perl.appender.AppFile.filename = " . ($logFile || 'dta-tokwrap.log') . "
log4perl.appender.AppFile.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.AppFile.layout.ConversionPattern = %d{yyyy-mm-dd hh:mm:ss} %G[%P] %p: %c: %m%n
  ";
  DTA::TokWrap->logInit(\$logConf);
}

##-- defaults: targets
if (!@targets) {
  @targets = @defaultTargets;
} else {
 @targets = map { split(/[\,\;\s]+/,$_) } @targets;
}

##-- create $tw
our $tw = DTA::TokWrap->new(%twopts)
  or die("$prog: could not create DTA::TokWrap object");

##-- debug: dump XSL?
if (defined($dump_xsl_prefix)) {
  $tw->{mkbx0}->dump_hint_stylesheet($dump_xsl_prefix."mkbx0_hint.xsl");
  $tw->{mkbx0}->dump_sort_stylesheet($dump_xsl_prefix."mkbx0_sort.xsl");
  $tw->{standoff}->dump_t2s_stylesheet($dump_xsl_prefix."standoff_t2s.xsl");
  $tw->{standoff}->dump_t2w_stylesheet($dump_xsl_prefix."standoff_t2w.xsl");
  $tw->{standoff}->dump_t2a_stylesheet($dump_xsl_prefix."standoff_t2a.xsl");
  exit(0);
}

##-- options: pseudo-make: make|gen
our $makeKeySub = $docopts{class}->can("${makeKeyAct}Key")
  or die("$prog: no method for $docopts{class}->${makeKeyAct}Key()");

##-- profiling
#our $tv_started = [gettimeofday];

##-- ye olde loope
our ($doc);
our $progrc=0;
our ($filerc,$target);
foreach $f (@ARGV) {
  $filerc = processFile($f);
  if ($@ || !$filerc) {
    vmsg1(0,"error processing XML file '$f': $@");
    ++$progrc;
  }
}

##-- profiling
$tw->logProfile($logProfile) if ($logProfile && $progrc==0);


exit($progrc); ##-- exit status

__END__

##===============================================================================
=pod

=head1 NAME

dta-tokwrap.perl - top-level tokenizer wrapper for DTA XML documents

=cut

##===============================================================================
=pod

=head1 SYNOPSIS

 dta-tokwrap.perl [OPTIONS] XMLFILE(s)...
 
 General Options:
  -help                  # show this help message
  -man                   # show complete manpage
  -verbose LEVEL         # set verbosity level (0<=level<=3; default=0)
 
 Make Emulation Options:
  -targets TARGETS       # set build targets (default='all')
  -make , -nomake        # do/don't emulate make-style dependency tracking (default=don't)
  -remake                # force rebuilding of all targets (implies -make)
  -force-target TARGET   # for -make mode, force rebuilding of TARGET
  -force                 # alias for -force-target=all
  -noforce               # overrides all preceeding -force and -force-target flags
 
 Subprocessor Options:
  -inplace , -noinplace  # do/don't use locally built programs if available (default=do)
  -sb-xpath XPATH        # add sentence-break hints on XPATH (element) open and close
  -wb-xpath XPATH        # add word-break hints on XPATH (element) open and close
  -procopt OPT=VALUE     # set arbitrary subprocessor options
 
 I/O Options:
  -outdir OUTDIR         # set output directory (default=.)
  -tmpdir TMPDIR         # set temporary directory (default=$ENV{DTATW_TMP} or OUTDIR)
  -keep , -nokeep        # do/don't keep temporary files (default=don't)
  -format , -noformat    # do/don't pretty-print XML output (default=do)
  -dump-xsl PREFIX       # dump generated XSL stylesheets to PREFIX*.xsl and exit
 
 Logging Options:
  -log-config RCFILE     # use Log::Log4perl configuration file RCFILE (default=internal)
  -log-level LEVEL       # set minimum log level
  -log-file LOGFILE      # log to file LOGFILE (default=none)
  -stderr  , -nostderr   # do/don't log to console (default=do)
  -profile , -noprofile  # do/don't log profiling information (default=do)
  -silent  , -quiet      # alias for -verbose=0 -log-level=FATAL -notrace
 
 Trace and Debugging Options:
  -dummy , -nodummy      # don't/do actually run any subprocessors (default=do)
  -trace , -notrace      # do/don't log trace messages (default: depends on -verbose)
  -traceAll              # enable logging of all possible trace messages
  -notraceAll            # disable logging of all possible trace messages
  -traceLevel LEVEL      # set trace logging level (default='trace')
  -traceX, -notraceX     # do/don't trace "X" (X={Open|Load|Save|Make|...})
  -traceXLevel LEVEL     # set log level for "X" traces (X={Open|...})

=cut

##===============================================================================
=pod

=head1 OPTIONS

=cut

##----------------------------------------------------------------------
=pod

=head2 General Options

=over 4

=item -help

Display a short help message and exit.

=item -man

Display the complete program manpage and exit.

=item -verbose LEVEL

Set verbosity level (0<=level<=3; default=0)

=back

=cut

##----------------------------------------------------------------------
=pod

=head2 Make Emulation Options

=over 4

=item -targets TARGETS

Set build targets (default=L</all>).
Multiple TARGETS may be separated by whitespace, commas, or
by passing multiple -targets options.
See L</"Known Targets"> for a list of currently defined targets.

=item -make , -nomake

Do/don't emulate experimental F<make>-style dependency tracking (default=don't).
Use of C<-make> mode may be faster (because it requires less file I/O).

=item -remake

Force rebuilding of all targets (implies L<-make|/"-make , -nomake">).

=item -force-target TARGET

For L<-make|/"-make , -nomake"> mode, force rebuilding of TARGET.

=item -force

Alias for L<-force-target|/"-force-target TARGET">C<=all>

=item -noforce

Overrides all preceeding L</-force> and L<-force-target|/"-force-target TARGET"> flags.

=back

=cut

##----------------------------------------------------------------------
=pod

=head2 Subprocessor Options:

=over 4

=item -inplace , -noinplace

Do/don't use locally built programs if available (default=do).
This is useful if you want to test a development version (C<-inplace>)
and an installed system version (C<-noinplace>) of this package
on the same machine.

=item -sb-xpath XPATH

Tells the C<mkbx0> subprocessor
to add sentence-break hints on XPATH (which should resolve only to element nodes) open and close.
XPATH is included in the generated F<hint.xsl> XSL stylesheet as a C<match>
item, so it can include e.g. top-level unions, but no nested unions.

This option may be specified more than once.

=item -wb-xpath XPATH

Tells the C<mkbx0> subprocessor
to add sentence-break hints on XPATH (which should resolve only to element nodes) open and close.
Same caveats as for L</"-sb-xpath XPATH">

This option may be specified more than once.

=item -procopt OPT=VALUE

Set an arbitrary subprocessor option OPT to VALUE.
See subprocessor module documentation for available options.

=back

=cut

##----------------------------------------------------------------------
=pod

=head2 I/O Options

=over 4

=item -outdir OUTDIR

Set output directory (default=.)

=item -tmpdir TMPDIR

Set directory for storing temporary files.  Default value is
taken from the environment variable C<$DTATW_TMP> if it is set,
otherwise the default is the value of OUTDIR (see L<-outdir|/"-outdir OUTDIR">).

=item -keep , -nokeep

Do/don't keep temporary files, rather than deleting them
when they are no longer needed (default=don't).

=item -format , -noformat

Do/don't pretty-print XML output when possible (default=do).

=item -dump-xsl PREFIX

Dumps generated XSL stylesheets to PREFIX*.xsl and exit.
Useful for debugging.
Causes the following files to be written:

 ${PREFIX}mkbx0_hint.xsl    # hint insertion
 ${PREFIX}mkbx0_sort.xsl    # serialization sort-key generation
 ${PREFIX}standoff_t2s.xsl  # master XML to sentence standoff
 ${PREFIX}standoff_t2w.xsl  # master XML to token standoff
 ${PREFIX}standoff_t2a.xsl  # master XML to analysis standoff

=back

=cut

##----------------------------------------------------------------------
=pod

=head2 Logging Options

=over 4

=item -log-config RCFILE

Use Log::Log4perl configuration file F<RCFILE>,
rather than the default internal configuration.
See L<Log::Log4perl(3pm)|Log::Log4perl> for details
on the syntax of F<RCFILE>.

=item -log-level LEVEL

Set minimum log level.
Only effective if the default (internal) log configuration is being used.

=item -log-file LOGFILE

Send log output to file F<LOGFILE> (default=none).
Only effective if the default (internal) log configuration is being used.

=item -stderr  , -nostderr

Do/don't log to console (default=do).
Only effective if the default (internal) log configuration is being used.

=item -profile , -noprofile

Do/don't log profiling information (default=do).

=item -silent  , -quiet

Alias for C<-verbose=0 -log-level=FATAL -notrace>.

=back

=cut

##----------------------------------------------------------------------
=pod

=head2 Trace and Debugging Options

=over 4

=item -dummy , -nodummy

Don't/do actually run any subprocessors (default=do)

=item -trace , -notrace

Do/don't log trace messages (default: depends on the current C<-verbose>
level; see L<-verbose|/"-verbose LEVEL">).

=item -traceAll

Enable logging of all possible trace messages.
B<Warning>: this generates a lot of log output.

=item -notraceAll

Disable logging of all possible trace messages.

=item -traceLevel LEVEL

Set log level to use for trace messages (default='trace').
C<LEVEL> is one of the following: C<trace, debug, info, warn, error, fatal>.
Any other value for C<LEVEL> causes trace messages not to be logged.

=item -traceX , -notraceX

Do/don't log trace messages for the trace flavor I<X>,
where I<X> is one of the following:

 Open   # document object open() method
 Close  # document object close() method
 Load   # load document data file
 Save   # save document data file
 Make   # document target (re-)making (including status-check)
 Gen    # document target (re-)generation
 Proc   # subprocessor operation
 Run    # external system command

=item -traceXLevel LEVEL

Set log level for I<X>-type traces to LEVEL.
I<X> is a trace message flavor as described
in L<-traceX|/"-traceX , -notraceX">, and
LEVEL is as described in L<-traceLevel|/"-traceLevel LEVEL">.

=back

=cut

##===============================================================================
=pod

=head1 ARGUMENTS

All other command-line arguments are assumed to be filenames of
DTA "base-format" XML files,
which are simply (TEI-conformant) UTF-8 encoded XML files with one C<E<lt>cE<gt>>
element per character:

=over 4

=item *

the document B<MUST> be encoded in UTF-8,

=item *

all text nodes to be tokenized should be descendants of a C<E<lt>cE<gt>> element
which is itself a descendant of a C<E<lt>textE<gt>> element (XPath=C<//text//c//text()>),

=item *

the document should contain exactly one such C<E<lt>cE<gt>> element for
each I<logical character>
which may be passed to the tokenizer,

=item *

no C<E<lt>cE<gt>> element may be a descendant of another C<E<lt>cE<gt>> element,
and

=item *

if stand-off targets are to be built (the default),
each C<E<lt>cE<gt>> element should have a valid C<xml:id> attribute.

=back

=cut


##===============================================================================
=pod

=head1 DESCRIPTION

This program is intended to provide a flexible high-level command-line interface
to the tokenization of DTA "base-format" XML documents, generating
I<e.g.> sentence-, token-, and analysis-level standoff XML annotations for
each input document.

The problem can be run in one of two main modes; see L</"Modes of Operation"> for details on these.
In either mode, it can be used either as a standalone batch-processor for
one or more input documents, or called by a superordinate build system, I<e.g.>
GNU C<make> (see C<make(1)>).  Program operation is controlled primarily
by the specification of one or more "targets" to build for each input document;
see L</"Known Targets"> for details.

=cut

##----------------------------------------------------------------------
=pod

=head2 Modes of Operation

The program can be run in one of two modes of operation,
L</"-make Mode"> and L</"-nomake Mode">.

=head3 -make Mode

In this (experimental) mode, the program attempts to emulate the dependency tracking
features of C<make> by (re-)building only those targets which either
do not yet exist, or which are older than one or more of their dependencies.
Since some dependencies are ephemeral, existing only in RAM during
a single program run, this can mean a lot of pain for comparatively little gain.

-make mode is enabled by specifying the L<-make|/"-make , -nomake"> option
on the command-line.

=head3 -nomake Mode

In this (experimental) mode, no implicit dependency tracking is
attempted, and all required data files (input, "temporary", and/or output)
must exist when the requested target is built; otherwise an error results.
-nomake mode can be somewhat slower than -make mode, since "temporary"
data (which in -make mode are RAM-only ephemera) may need to be bounced off
the filesystem.

-nomake mode is the default mode, and may be (re-)enabled (overriding
any preceding C<-make> option) 
by specifying the L<-nomake|/"-make , -nomake"> option
on the command-line.

=cut

##----------------------------------------------------------------------
=pod

=head2 Known Targets

=head3 -make Targets

The following targets are known values for the
L<-targets|/"-targets TARGETS"> option in L<-make Mode>:

=over 4

=item all

=item (not yet documented)

=back



=head3 -nomake Targets

The following targets are known values for the
L<-targets|/"-targets TARGETS"> option in L<-nomake Mode>:

=over 4

=item mkindex

B<Alias(es):> cx sx tx xx

B<Input(s):> FILE.xml

B<Output(s):> FILE.cx, FILE.sx, FILE.tx

Creates temporary
"character index" F<FILE.cx> (CSV),
"structure index" F<FILE.sx> (XML without C<E<lt>cE<gt>> elements),
and
"text index" F<FILE.tx> (raw text, unserialized)
for each input document F<FILE.xml>.

=item mkbx0

B<Alias(es):> bx0

B<Input(s):> FILE.sx

B<Output(s):> FILE.bx0

Creates temporary
hint- and serialization index F<FILE.bx0>
for each input document F<FILE.xml>

=item mkbx

B<Alias(es):> mktxt bx txt

B<Input(s):> FILE.bx0, FILE.tx

B<Output(s):> FILE.bx, FILE.txt

Creates temporary serialized block-index file F<FILE.bx>
and serialized text file F<FILE.txt>
for each input document F<FILE.xml>.

=item mktok

B<Alias(es):> tokenize tok t tt

B<Input(s):> FILE.txt

B<Output(s):> FILE.t

Creates temporary CSV-format tokenizer output file F<FILE.t>
for each input document F<FILE.xml>

=item mktxml

B<Alias(es):> tok2xml xtok txml ttxml tokxml

B<Input(s):> FILE.t, FILE.bx, FILE.cx

B<Output(s):> FILE.t.xml

Creates master tokenized XML output file F<FILE.t.xml>
for each input document F<FILE.xml>

=item mksxml

B<Alias(es):> mksos sosxml sosfile sxml

B<Input(s):> FILE.t.xml

B<Output(s):> FILE.s.xml

Creates sentence-level stand-off XML file FILE.s.xml
for each input document F<FILE.xml>

=item mkwxml

B<Alias(es):> mksow sowxml sowfile wxml

B<Input(s):> FILE.t.xml

B<Output(s):> FILE.w.xml

Creates token-level stand-off XML file FILE.w.xml
for each input document F<FILE.xml>

=item mkaxml

B<Alias(es):> mksoa sowaml soafile axml

B<Input(s):> FILE.t.xml

B<Output(s):> FILE.a.xml

Creates token-analysis-level stand-off XML file FILE.a.xml
for each input document F<FILE.xml>

=item mkstandoff

B<Alias(es):> standoff so mkso

Alias for L<mksxml>, L<mkwxml>, L<mkaxml>.

=item all

B<Alias(es):> (none)

B<Input(s):> FILE.xml

B<Output(s):> FILE.t.xml, FILE.s.xml, FILE.w.xml, FILE.a.xml

Alias for all targets required to generated
the target's output files (master tokenized file and stand-off files)
from the input document, run in the proper order.

=back

=cut

##===============================================================================
=pod

=head1 SEE ALSO

perl(1),
...

=cut

##===============================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut
