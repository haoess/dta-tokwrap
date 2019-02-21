## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Base
## Author: Bryan Jurish <moocow@cpan.org>
## Description: DTA tokenizer wrappers: base class

package DTA::TokWrap::Base;
use DTA::TokWrap::Version;
use DTA::TokWrap::Logger;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Logger);

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: HASH:
##    {
##     %args,
##    }
##  + calls $obj->init() after instantiation
sub new {
  my $that = shift;
  my $obj = bless({
		   ##-- defaults
		   $that->defaults(),

		   ##-- user args
		   @_
		  }, ref($that)||$that);
  return $obj->init();
}

## %defaults = CLASS_OR_OBJ->defaults()
##  + called by constructor
sub defaults {
  return qw();
}

## $obj = $obj->init()
##  + dummy method
sub init {
  return $_[0];
}

##==============================================================================
## Methods
##==============================================================================

#(nothing here)

1; ##-- be happy

__END__

##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, then edited
=pod

=cut

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Base - DTA tokenizer wrappers: base class

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Base;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = $CLASS_OR_OBJ->new(%args);        ##-- inheritable constructor
 %defaults = $CLASS_OR_OBJ->defaults();   ##-- set static defaults
 $obj = $obj->init();                     ##-- set dynamic defaults

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Base provides an abstract base class for all object classes
in the
DTA::TokWrap distribution

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Base: Constants
=pod

=head2 Constants

=over 4

=item Variable: @ISA

DTA::TokWrap::Base inherits from L<DTA::TokWrap::Logger|DTA::TokWrap::Logger>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Base: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $obj = $CLASS_OR_OBJ->new(%args);

Generic constructor.  %args is a hash of
subclass-dependent constructor options.

The default implementation calls
$CLASS_OR_OBJ-E<gt>defaults() before
the new object is instiated, and and
$obj-E<gt>init() afterwords.

=item defaults

 %defaults = CLASS_OR_OBJ->defaults();

Subclasses may define a C<defaults()> method to
set static (class-dependent) object defaults.
The return value %defaults should be an object option
hash.

The default implementation just returns an empty hash.

=item init

 $obj = $obj->init();

Subclasses may define an C<init()> method to
compute dynamic (object-dependent) object defaults.

The default implementation does nothing.

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

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2018 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut


