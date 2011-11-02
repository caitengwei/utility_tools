#!/usr/bin/perl
use strict;
use warnings;
use IO::Scalar;
use LWP::UserAgent;
use HTML::TreeBuilder::XPath;
use URI::Escape;
use Data::Dumper;
use encoding "utf-8";

my $keyword = $ARGV[0];
die "You must pass a Chinese/English word as parameter" if ( ! $keyword );

my $url  = 'http://dict.youdao.com/search?q=KEYW0RD&ue=utf8';
$keyword = uri_escape( $keyword );
$url     =~ s/KEYW0RD/$keyword/;

my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->env_proxy;

my $page = $ua->get( $url );
die "Cannot connect to youdao dictionary" unless ( $page->is_success );

my $buffer;
my $screen = IO::Scalar->new( \$buffer );
my $tree   = HTML::TreeBuilder::XPath->new_from_content( $page->decoded_content );

get_translation( $tree, $screen );
print $buffer;

END {
    $tree->delete();
}

sub get_translation {
    my ( $tree, $screen ) = @_;
    my $indent = 2;
    if ( ! $tree->exists('//div[@class=\'trans-wrapper\'][not(@id)]') ) {
        $screen->print( "Cannot find the translation on the page\n" );
        return 1;
    }
    else {
        # Get the spell and phonetic of the word
        $screen->print( $tree->findvalue('//div[@class=\'trans-wrapper\'][not(@id)]/h2'), "\n" );
        $screen->print( "\n" );
    }

    if ( $tree->exists('//div[@id=\'eTransform\']') ) {
        # Get the basic translation of the word
        $screen->print( $tree->findvalue('//div[@id=\'eTransform\']/h3/span/a[@rel=\'#etcTrans\']/span'), "\n" );
        my @translation_list = $tree->findvalues( '//div[@id=\'eTransform\']/div/div[@id=\'etcTrans\']/ul/' . 'li' );
        if ($#translation_list == -1 ) {
            # If didn't get any translation, it may be a chinese word
            @translation_list = $tree->findvalues( '//div[@id=\'eTransform\']/div/div[@id=\'etcTrans\']/ul/' . 'p' );
        }
        foreach (@translation_list) {
            $screen->print( ' ' x $indent, trim( $_ ), "\n" );
        }
        $screen->print( "\n" );
    }

    if ( $tree->exists('//div[@id=\'examples\']') ) {
        # Get the examples of the word
        my @examples_id   = qw(bilingual originalSound authority);
        my @examples_name = split( /\s+/, trim( $tree->findvalue('//div[@id=\'examples\']/h3') ) );
        foreach my $index ( 0 .. 2 ) {
            my $xpath = '//div[@id=\'examples\']/div/div[@id=\'' . $examples_id[$index] . '\']';
            next if ( ! $tree->exists( $xpath ) );
            $screen->print( shift @examples_name, "\n" );
            my @examples_list    = $tree->findvalues( "$xpath/ul/li/" . "p[not(\@class)]" );
            my $is_a_translation = 0;
            foreach (@examples_list) {
                $screen->print( ' ' x $indent, $is_a_translation ? "~ $_" : $_, "\n" );
                $is_a_translation ^= 1 if ( $index < 2 );
            }
            $screen->print( "\n" );
        }
    }
    
}

sub trim {
    my $string = shift;
    $string =~ s/^\s*(.*?)\s*$/$1/;
    return $string;
}

