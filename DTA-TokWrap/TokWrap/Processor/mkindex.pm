## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::mkindex
## Author: Bryan Jurish <jurish@bbaw.de>
## Description: DTA tokenizer wrappers: dtatw-mkindex

package DTA::TokWrap::Processor::mkindex;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :time);
use DTA::TokWrap::Processor;

use File::Basename qw(basename dirname);

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor);

##==============================================================================
## Constructors etc.
##==============================================================================

## $mi = CLASS_OR_OBJ->new(%args)
##  + %args:
##    mkindex => $path_to_dtatw_mkindex, ##-- default: search
##    inplace => $bool,                  ##-- prefer in-place programs for search?

## %defaults = CLASS->defaults()
sub defaults {
  my $that = shift;
  return (
	  $that->SUPER::defaults(),
	  mkindex=>undef,
	  inplace=>1,
	 );
}

## $mi = $mi->init()
sub init {
  my $mi = shift;

  ##-- search for mkindex program
  if (!defined($mi->{mkindex})) {
    $mi->{mkindex} = path_prog('dtatw-mkindex',
			       prepend=>($mi->{inplace} ? ['.','../src'] : undef),
			       warnsub=>sub {$mi->logconfess(@_)},
			      );
  }

  return $mi;
}

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->mkindex($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    xmlfile => $xmlfile, ##-- source XML file
##    cxfile  => $cxfile,  ##-- output character index filename
##    sxfile  => $sxfile,  ##-- output structure index filename
##    txfile  => $txfile,  ##-- output structure index filename
##    mkindex_stamp0 => $f, ##-- (output) timestamp of operation begin
##    mkindex_stamp  => $f, ##-- (output) timestamp of operation end
##    cxfile_stamp   => $f, ##-- (output) timetamp of operation end
##    sxfile_stamp   => $f, ##-- (output) timetamp of operation end
##    txfile_stamp   => $f, ##-- (output) timetamp of operation end
sub mkindex {
  my ($mi,$doc) = @_;
  $doc->setLogContext();

  ##-- log, stamp
  $mi->vlog($mi->{traceLevel},"mkindex()");
  $doc->{mkindex_stamp0} = timestamp(); ##-- stamp

  ##-- sanity check(s)
  $mi = $mi->new if (!ref($mi));
  $mi->logconfess("mkindex(): no dtatw-mkindex program") if (!$mi->{mkindex});
  $mi->logconfess("mkindex(): XML source file not readable") if (!-r $doc->{xmlfile});

  ##-- run program
  my $rc = runcmd($mi->{mkindex}, @$doc{qw(xmlfile cxfile sxfile txfile)});
  $mi->logconfess(ref($mi)."::mkindex() mkindex program failed: $!") if ($rc!=0);
  $mi->logconfess(ref($mi)."::mkindex() failed to create output file(s)")
    if ( ($doc->{cxfile} && !-e $doc->{cxfile})
	 || ($doc->{sxfile} && !-e $doc->{sxfile})
	 || ($doc->{txfile} && !-e $doc->{txfile}) );

  my $stamp = timestamp();
  $doc->{"${_}_stamp"} = $stamp foreach (qw(mkindex cxfile sxfile txfile));
  return $doc;
}


1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::mkindex - DTA tokenizer wrappers: dtatw-mkindex

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::mkindex;
 
 $mi = DTA::TokWrap::Processor::mkindex->new(%opts);
 $doc_or_undef = $mi->mkindex($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::mkindex provides an object-oriented
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor> wrapper
around the F<dtatw-mkindex> C program
for L<DTA::TokWrap::Document|DTA::TokWrap::Document> objects.

Most users should use the high-level
L<DTA::TokWrap|DTA::TokWrap> wrapper class
instead of using this module directly.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkindex: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::mkindex
inherits from
L<DTA::TokWrap::Processor|DTA::TokWrap::Processor>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkindex: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = $CLASS_OR_OBJECT->new(%args);

Constructor.

%args, %$obj:

 mkindex => $path_to_dtatw_mkindex, ##-- default: search
 inplace => $bool,                  ##-- prefer in-place programs for search?

=item defaults

 %defaults = $CLASS->defaults();

Static class-dependent defaults.

=item init

 $mi = $mi->init();

Dynamic object-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::mkindex: Methods
=pod

=head2 Methods

=over 4

=item mkindex

 $doc_or_undef = $CLASS_OR_OBJECT->mkindex($doc);

Runs the F<dtatw-mkindex> program on the 
L<DTA::TokWrap::Document|DTA::TokWrap::Document> object
$doc.

Relevant %$doc keys:

 xmlfile => $xmlfile,  ##-- (input) source base-format XML file
 cxfile  => $cxfile,   ##-- (output) character index filename
 sxfile  => $sxfile,   ##-- (output) structure index filename
 txfile  => $txfile,   ##-- (output) structure index filename
 ##
 mkindex_stamp0 => $f, ##-- (output) timestamp of operation begin
 mkindex_stamp  => $f, ##-- (output) timestamp of operation end
 cxfile_stamp   => $f, ##-- (output) timetamp of operation end
 sxfile_stamp   => $f, ##-- (output) timetamp of operation end
 txfile_stamp   => $f, ##-- (output) timetamp of operation end

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

Copyright (C) 2009-2014 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut


