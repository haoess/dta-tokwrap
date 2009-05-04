## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::tokenize.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA tokenizer wrappers: tokenizer: placeholder for tomasoblabla

package DTA::TokWrap::Processor::tokenize;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :slurp :time);
use DTA::TokWrap::Processor;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

##==============================================================================
## Constructors etc.
##==============================================================================

## $tz = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + static class-dependent defaults
##  + %args, %defaults, %$tz:
##    tomata2 => $path_to_dwds_tomasotath, ##-- tokenizer program; default: search
##    tomata2opts => \@options,            ##-- additional options for tokenizer program
##    inplace => $bool,                    ##-- prefer in-place programs for search?
sub defaults {
  my $that = shift;
  return (
	  $that->SUPER::defaults(),
	  tomata2=>undef,
	  tomata2opts=>['--to', '--to-offset'], ##-- options
	  inplace=>1,
	 );
}

## $tz = $tz->init()
sub init {
  my $tz = shift;

  ##-- search for tokenizer program
  if (!defined($tz->{tomata2})) {
    $tz->{tomata2} = path_prog('dwds_tomasotath',
			       prepend=>($tz->{inplace} ? ['.','../src'] : undef),
			       warnsub=>sub {$tz->logconfess(@_)},
			      );
  }

  return $tz;
}

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tokenize($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    txtfile => $txtfile,  ##-- (input) serialized text file
##    tokdata => $tokdata,  ##-- (output) tokenizer output data (string)
##    tokenize_stamp0 => $f, ##-- (output) timestamp of operation begin
##    tokenize_stamp  => $f, ##-- (output) timestamp of operation end
##    tokdata_stamp => $f,   ##-- (output) timestamp of operation end
## + may implicitly call $doc->mkbx() and/or $doc->saveTxtFile()
sub tokenize {
  my ($tz,$doc) = @_;

  ##-- log, stamp
  $tz->vlog($tz->{traceLevel},"tokenize($doc->{xmlbase})");
  $doc->{tokenize_stamp0} = timestamp();

  ##-- sanity check(s)
  $tz = $tz->new if (!ref($tz));
  $tz->logconfess("tokenize($doc->{xmlbase}): no dwds_tomasotath program found")
    if (!$tz->{tomata2});
  $tz->logconfess("tokenize($doc->{xmlbase}): no .txt file defined")
    if (!defined($doc->{txtfile}));
  $tz->logconfess("tokenize($doc->{xmlbase}): .txt file '$doc->{txtfile}' not readable")
    if (!-r $doc->{txtfile});

  ##-- run program
  $doc->{tokdata} = '';
  my $cmd = join(' ',
		 map {"'$_'"}
		 ($tz->{tomata2},
		  ($tz->{tomata2opts} ? @{$tz->{tomata2opts}} : qw()),
		  $doc->{txtfile},
		 ));
  my $cmdfh = IO::File->new("$cmd |")
    or $tz->logconfess("tokenize($doc->{xmlbase}): open failed for pipe ($cmd |): $!");
  slurp_fh($cmdfh, \$doc->{tokdata});
  $cmdfh->close();

  ##-- finalize
  $doc->{ntoks} = $tz->nTokens(\$doc->{tokdata});
  $doc->{tokenize_stamp} = $doc->{tokdata_stamp} = timestamp(); ##-- stamp
  return $doc;
}


##==============================================================================
## Utilities
##==============================================================================

## $ntoks = $tz->nTokens(\$tokdata)
##  + get number of tokens in \$tokdata (regex hack)
sub nTokens {
  #my ($tz,$tokdatar) = @_;
  return scalar( @{[ ${$_[1]} =~ /^(?!%%).+$/mg ]} );
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::tokenize - DTA tokenizer wrappers: tokenizer: default (NYI)

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::tokenize;
 
 $tz = DTA::TokWrap::Processor::tokenize->new(%args);
 $doc_or_undef = $tz->tokenize($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

B<WARNING>: this class is currently just a placeholder for the
"official" low-level tokenizer (ToMaSoTaTh).  Until such time
as the official tokenizer is functional, please use the
L<DTA::TokWrap::Processor::tokenize::dummy|DTA::TokWrap::Processor::tokenize::dummy>
sub-class, which uses a simple locally-built low-level tokenizer.

DTA::TokWrap::Processor::tokenize provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
for the tokenization of serialized text files
for L<DTA::TokWrap::Document|DTA::TokWrap::Document> objects.

Most users should use the high-level
L<DTA::TokWrap|DTA::TokWrap> wrapper class
instead of using this module directly.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::tokenize
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $tz = $CLASS_OR_OBJ->new(%args);

%args, %$tz: (none yet)

=item defaults

 %defaults = CLASS->defaults();

Static class-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize: Methods
=pod

=head2 Methods

=over 4

=item tokenize

 $doc_or_undef = $CLASS_OR_OBJECT->tokenize($doc);

Runs the low-level tokenizer on the
serialized text from the
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object $doc.

Relevant %$doc keys:

 txtfile => $txtfile,  ##-- (input) serialized text file (uses $doc->{bxdata} if $doc->{txtfile} is not defined)
 bxdata  => \@bxdata,  ##-- (input) block data, used to generate $doc->{txtfile} if not present
 tokdata => $tokdata,  ##-- (output) tokenizer output data (string)
 ##
 tokenize_stamp0 => $f, ##-- (output) timestamp of operation begin
 tokenize_stamp  => $f, ##-- (output) timestamp of operation end
 tokdata_stamp => $f,   ##-- (output) timestamp of operation end

may implicitly call $doc-E<gt>mkbx() and/or $doc-E<gt>saveTxtFile()
(but shouldn't).

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## See Also
##======================================================================

=pod

=head1 SEE ALSO

L<DTA::TokWrap::Intro(3pm)|DTA::TokWrap::Intro>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
...

=cut

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
