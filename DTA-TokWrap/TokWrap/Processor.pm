## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA tokenizer wrappers: base class for processor modules

package DTA::TokWrap::Processor;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:time);

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = ('DTA::TokWrap::Base');

##==============================================================================
## Constructors etc.
##==============================================================================

## $p = CLASS_OR_OBJ->new(%args)
##  + %args, %$p:
##    traceLevel => $level,   ##-- trace level for DTA::TokWrap::Logger subs

## %defaults = CLASS->defaults()
sub defaults {
  return
    (
     $_[0]->SUPER::defaults,
     traceLevel => 'trace',
     #dummy => 0,
    );
}

## $p = $p->init()

##==============================================================================
## Methods: Document Processing
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->${PROCESS}($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##   (list of input/output keys which ${PROCESS}() sub reads or writes

## $doc_or_undef = $CLASS_OR_OBJECT->process($doc)
## + perform default processing on $doc
## + default implementation calls $CLASS_OR_OBJECT->${BASENAME}($doc) if available,
##   where $BASENAME = ($CLASS=~s/^.*:://); otherwise just returns $doc
sub process {
  my ($p,$doc) = @_;
  (my $base = (ref($p)||$p)) =~ s/^.*:://;
  my $sub = UNIVERSAL::can($p,$base);
  return $sub ? $sub->($p,$doc) : $doc;
}

##==============================================================================
## Methods: Document Processing
##==============================================================================

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, and edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor - DTA tokenizer wrappers: base class for processor modules

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor;
 
 ##========================================================================
 ## Constructors etc.
 
 %defaults = $CLASS->defaults();   ##-- static class-dependent defaults
 
 ##========================================================================
 ## Methods: Document Processing
 
 $doc_or_undef = $CLASS_OR_OBJECT->process($doc); ##-- wrapper

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

The DTA::TokWrap::Processor package provides an abstract base class
which subsumes document-processing modules included in the DTA::TokWrap
distribution.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor inherits from L<DTA::TokWrap::Base|DTA::TokWrap::Base>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item defaults

 %defaults = $CLASS_OR_OBJ->defaults();

Known defaults added by this class:

 traceLevel => $how,   ##-- trace level for DTA::TokWrap::Logger subs

Default $how = 'trace'.
See L<DTA::TokWrap::Logger-E<gt>vlog()|DTA::TokWrap::Logger/vlog> for
known values of $how.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor: Methods: Document Processing
=pod

=head2 Methods: Document Processing

=over 4

=item process

 $doc_or_undef = $CLASS_OR_OBJECT->process($doc);

Performs sub-processing operation on $doc.

Default implementation calls $CLASS_OR_OBJECT-E<gt>${BASENAME}($doc) if available,
where $BASENAME = ($CLASS=~s/^.*:://); otherwise just returns $doc (i.e. does nothing).

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl
=pod

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

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut

=cut


=cut

