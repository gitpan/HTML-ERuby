package HTML::ERuby;
# $Id: ERuby.pm,v 1.2 2002/04/13 11:21:27 ikechin Exp $
use strict;
use vars qw($VERSION $ERUBY_TAG_RE);
use IO::File;
use Carp ();
use Inline Ruby =><<'END';
def _rb_eval(str)
  eval(str)
end
END

$ERUBY_TAG_RE = qr/(<%%)|(%%>)|(<%=)|(<%#)|(<%)|(%>)|(\n)/so;
$VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = bless {
    }, $class;
    $self;
}

sub compile {
    my ($self, %args) = @_;
    my $data;
    if ($args{filename}) {
	$data = $self->_open_file($args{filename});
    }
    elsif ($args{scalarref}) {
	$data = ${$args{scalarref}};
    }
    elsif ($args{arrayref}) {
	$data = join('', @{$args{arrayref}});
    }
    else {
	Carp::croak("please specify ERuby document");
    }
    my $src = $self->_parse(\$data);
    return _rb_eval($src);
}

sub _open_file {
    my ($self, $filename) = @_;
    local $/ = undef;
    my $f = IO::File->new($filename, "r") or Carp::croak($!);
    my $data = $f->getline;
    $f->close;
    return $data;
}

# copy from erb/compile.rb and Perlize :)
sub _parse {
    my($self, $scalarref) = @_;
    my $src = q/_erb_out = '';/;
    my @text = split($ERUBY_TAG_RE, $$scalarref);
    my @content;
    my @cmd = ("_erb_out = ''\n");
    my $stag;
    my $token;
    for my $token(@text) {
	if ($token eq '<%%') {
	    push @content, '<%';
	    next;
	}
	if ($token eq '%%>') {
	    push @content, '%>';
	    next;
	}
	unless ($stag) {
	    if ($token eq '<%' || $token eq '<%=' || $token eq '<%#') {
		$stag = $token;
		my $str = join('', @content);
		if ($str) {
		    push @cmd, qq/_erb_out.concat '$str';/;
		}
		@content = ();
	    }
	    elsif($token eq "\n") {
		push @content, "\n";
		my $str = join('', @content);
		push @cmd, qq/_erb_out.concat '$str';/ if $str;
		@content = ();
	    }
	    else {
		push @content, $token;
	    }
	}
	else {
	    if ($token eq '%>') {
		my $str = join('', @content);
		if ($stag eq '<%') {
		    push @cmd, $str, "\n";
		}
		elsif ($stag eq '<%=') {
		    push @cmd, qq/_erb_out.concat( ($str).to_s );/;
		}
		elsif ($stag eq '<%#') {
		    # comment out SKIP!
		}
		@content = ();
		$stag = undef;
	    }
	    else {
		push @content, $token;
	    }
	}
    }
    if (@content) {
	my $str = join('', @content);
	push @cmd, qq/_erb_out.concat '$str';/;
    }
    push @cmd, '_erb_out;';
    return join('', @cmd);
}

1;

__END__

=pod

=head1 NAME

HTML::ERuby - ERuby processor for Perl.

=head1 SYNOPSIS

  use HTML::ERuby;
  my $compiler = HTML::ERuby->new;
  my $result = $compiler->compile(filename => './foo.rhtml');
  print $result;

=head1 DESCRIPTION

HTML::ERuby is a ERuby processor written in Perl.

parse ERuby document by Perl and evaluate by Ruby.

=head1 METHODS

=over 4

=item $compiler = HTML::ERuby->new

constructs HTML::ERuby object.

=item $result = $compiler->compile(\%option)

compile ERuby document and return result.
you can specify ERuby document as filename, scalarref or arrayref.

  $result = $compiler->compile(filename => $filename);
  
  $result = $compiler->compile(scalarref => \$rhtml);
  
  $result = $compiler->compile(arrayref => \@rhtml);

=back

=head1 CAVEATS

this module is experimental.

this module internal, using L<Inline::Ruby>. 
so, it will create a '_Inline' directory in your current directory.
but, you can specify it in the environment variable PERL_INLINE_DIRECTORY.

See the L<Inline> manpage for details.

=head1 AUTHOR

Author E<lt>ikebe@edge.co.jpE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Inline> L<Inline::Ruby>

http://www2a.biglobe.ne.jp/~seki/ruby/erb.html

http://www.modruby.net/

=cut
