## -*- Mode: CPerl; coding: utf-8 -*-

## File: DTA::TokWrap::Processor::tokenize1.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA tokenizer wrappers: tokenizer: post-processing hacks

package DTA::TokWrap::Processor::tokenize1;

use DTA::TokWrap::Version;  ##-- imports $VERSION, $RCDIR
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :slurp :time);
use DTA::TokWrap::Processor;
use DTA::TokWrap::Processor::tokenize;

use Encode qw(encode decode);
use Carp;
use strict;

use utf8;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor::tokenize);

##==============================================================================
## Constructors etc.
##==============================================================================

## $tp = CLASS_OR_OBJ->new(%args)
## %defaults = CLASS->defaults()
##  + static class-dependent defaults
##  + %args, %defaults, %$tp:
##    fixtok => $bool,                     ##-- if true (default), attempt to fix common tomata2-tokenizer errors
sub defaults {
  my $that = shift;
  return (
	  $that->SUPER::defaults(),
	  fixtok => 1,
	 );
}

## $tp = $tp->init()
sub init {
  my $tp = shift;

  ##-- defaults
  $tp->{fixtok} = 1 if (!exists($tp->{fixtok}));

  return $tp;
}

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tokenize1($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    tokdata0 => $tokdata0, ##-- (input)  raw tokenizer output (string)
##    tokdata1 => $tokdata1, ##-- (output) post-processed tokenizer output (string)
##    tokenize_stamp1 => $f, ##-- (output) timestamp of operation end
##    tokdata_stamp1  => $f, ##-- (output) timestamp of operation end
## + may implicitly call $doc->tokenize()
sub tokenize1 {
  my ($tp,$doc) = @_;

  ##-- log, stamp
  $tp = $tp->new if (!ref($tp));
  $tp->vlog($tp->{traceLevel},"tokenize1($doc->{xmlbase}): fixtok=".($tp->{fixtok} ? 1 : 0));

  ##-- sanity check(s)
  #(none)

  ##-- get token data
  my $tdata0r = \$doc->{tokdata0};
  if (!defined($$tdata0r)) {
    $tdata0r = $doc->loadTokFile0()
      or $tp->logconfess("tokenize1($doc->{xmlbase}: could not load raw tokenizer data (*.t0)");
  }

  ##-- auto-fix?
  if (!$tp->{fixtok}) {
    $doc->{tokdata1} = $$tdata0r; ##-- just copy
  }
  else {
    my $data = decode('utf8',$$tdata0r);

    ##-- fix stupid interjections
    $tp->vlog($tp->{traceLevel},"autofix: re/ITJ");
    $data =~ s/^(re\t\d+ \d+)\tITJ$/$1/mg;

    ##-- fix: line-broken tokens: get list of suspects
    ## NOTE:
    ##  + we do this fix in 2 passes to allow some fine-grained checks (e.g. %nojoin_txt2)
    ##  + also, at least 1 dta file (kurz_sonnenwirth_1855.xml) caused the original single-regex
    ##    implementation to choke (or at least to churn cpu cycles for over 5 minutes wihthout
    ##    producing any results, for some as-yet-undetermined reason)
    ##  + the 2-pass approach using a simpler regex for the large buffer and the @-, @+ arrays
    ##    rather then ()-groups doesn't cause the same race-condition-like behavior... go figure
    ## -moocow Wed, 04 Aug 2010 13:37:25 +0200
    ##
    ## + hypens we might want to pay attention to:
    ##   CP_HEX   CP_DEC LEN_U8   CHR_L1     CHR_U8_C         BLOCK                   NAME
    ##   U+002D       45      1        -            -         Basic Latin             HYPHEN-MINUS
    ##   U+00AC      172      2        ¬      \xc2\xac        Latin-1 Supplement      NOT SIGN
    ##   U+2014     8212      3       [?] \xe2\x80\x94        General Punctuation     EM DASH
    ##    -- this is not really a connector, but it might be used somewhere!
    $tp->vlog($tp->{traceLevel},"autofix: linebreak: find suspects");
    my @suspects = qw();
    while (
	   $data =~ /
		      [[:alpha:]\'\-\x{ac}]*                        ##-- w1.text [modulo final "-"]
		      [\-\x{ac}]                                    ##--   : w1.final "-"
		      \t.*                                          ##--   : w1.rest
		      \n+                                           ##--   : EOT (EOS?) (w1 . w2)
		      [[:alpha:]\'\-\x{ac}]*                        ##-- w2.text [modulo final "."]
		      \.?                                           ##--   : w2.text: final "." (optional)
		      \t.*                                          ##--   : w2.rest
		      \n                                            ##--   : EOT (w1 w2 .)
		    /mxg
	  )
      {
	push(@suspects, [$-[0], $+[0]-$-[0]]);
      }

    ##-- fix: line-broken tokens: fix
    $tp->vlog($tp->{traceLevel},"autofix: linebreak: check \& apply");
    my %nojoin_txt2 = map {($_=>undef)} qw(und oder als wie noch sondern ſondern);

    my ($s_str, $txt1,$off1,$len1,$rest1, $txt2,$off2,$len2,$rest2, $repl);
    foreach (reverse @suspects) {
      $s_str = substr($data,$_->[0],$_->[1]);
      $repl  = undef;

      if (
	  $s_str =~ m/^([^\t\n]*)            ##-- $1: w1.txt
		      \t(\d+)\ (\d+)         ##-- ($2,$3): (w1.off, w1.len)
		      ([^\n]*)               ##-- $4: w1.rest
		      \n+                    ##-- w1.EOT (EOS?)
		      ([^\t\n]*)             ##-- $5: w2.txt
		      \t(\d+)\ (\d+)         ##-- ($6,$7): (w2.off, w2.len)
		      ([^\n]*)               ##-- $8: w2.rest
		      \n+$                   ##-- w2.EOT
		     /sx
	 ) {
	($txt1,$off1,$len1,$rest1, $txt2,$off2,$len2,$rest2) = ($1,$2,$3,$4, $5,$6,$7,$8);

	##-- skip vowel-less w1
	next if ($txt1 !~ /[aeiouäöüy]/);

	##-- skip common conjunctions as w2
	next if (exists($nojoin_txt2{$txt2}));

	##-- skip upper-case and vowel-less w2
	next if ($txt2 =~ /[[:upper:]]/ || $txt2 !~ /[aeiouäöüy]/);

	##-- check for abbrevs
	if ($txt2 =~ /\.$/ && $rest2 =~ /\bXY\b/) {
	  $repl = (
		   substr($txt1,0,-1).substr($txt2,0,-1)."\t$off1 ".(($off2+$len2)-$off1-1)."\n"
		   .".\t".($off2+$len2-1)." 1\t\$.\n"
		   ."\n"
		  );
	} elsif ($rest2 =~ /^(?:\tTRUNC)?$/) {
	  $repl = (
		   substr($txt1,0,-1).$txt2."\t$off1 ".(($off2+$len2)-$off1)."$rest2\n"
		  );
	}

	##-- DEBUG
	#print STDERR "  - SUSPECT: ($txt1 \@$off1.$len1 :$rest1)  +  ($txt2 \@$off2.$len2 :$rest2)  -->  ".(defined($repl) ? $repl : "IGNORE\n");
      } else {
	$tp->logwarn("tokenize1(): couldn't parse line-broken suspect line at t0-file offset $_->[0], length $_->[1] - skipping");
	next;
      }

      ##-- apply actual replacement
      substr($data,$_->[0],$_->[1]) = $repl if (defined($repl));
    }

    ##-- write data back to doc (encoded)
    $tp->vlog($tp->{traceLevel},"autofix: recode");
    $doc->{tokdata1} = encode('utf8',$data);
  }

  ##-- finalize
  $doc->{ntoks} = $tp->nTokens(\$doc->{tokdata1});
  $doc->{tokenize_stamp1} = $doc->{tokdata_stamp1} = timestamp(); ##-- stamp
  return $doc;
}

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::tokenize1 - DTA tokenizer wrappers: tokenizer post-processing

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::tokenize1;
 
 $tp = DTA::TokWrap::Processor::tokenize1->new(%args);
 $doc_or_undef = $tp->tokenize1($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::tokenize1 provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
for post-processing of raw tokenizer output
for L<DTA::TokWrap::Document|DTA::TokWrap::Document> objects.

Most users should use the high-level
L<DTA::TokWrap|DTA::TokWrap> wrapper class
instead of using this module directly.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize1: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::tokenize1
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize1: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $tp = $CLASS_OR_OBJ->new(%args);

%args, %$tp: (none yet)

=item defaults

 %defaults = CLASS->defaults();

Static class-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize1: Methods
=pod

=head2 Methods

=over 4

=item tokenize1

 $doc_or_undef = $CLASS_OR_OBJECT->tokenize1($doc);

Runs the low-level tokenizer on the
serialized text from the
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object $doc.

Relevant %$doc keys:

  tokdata0 => $tokdata0,  ##-- (input)  raw tokenizer output (string)
  tokdata1 => $tokdata1,  ##-- (output) post-processed tokenizer output (string)
  tokenize_stamp1 => $f,  ##-- (output) timestamp of operation end
  tokdata_stamp1  => $f,  ##-- (output) timestamp of operation end

may implicitly call $doc-E<gt>tokenize()
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

Copyright (C) 2010 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut