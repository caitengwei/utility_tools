#!/usr/bin/perl
use strict;
use warnings;
use IO::Scalar;
use LWP::UserAgent;
use HTML::TreeBuilder::XPath;
use URI::Escape;
use Data::Dumper;
use encoding "utf-8";

my $url     = 'http://dict.youdao.com/search?q=KEYW0RD&ue=utf8';
my %ele_map = (

    # Result area
    results_contents => q(//div[@id='results-contents']),

    # Word
    word     => q(//h2[@class='wordbook-js']),
    keyword  => q(//h2[@class='wordbook-js']/span[@class='keyword']),
    phonetic => q(//h2[@class='wordbook-js']/span[@class='phonetic']),

    # Trans
    basic_trans => q(//div[@id='phrsListTab']/div[@class='trans-container']/ul),
    addt_trans  => q(//div[@id='phrsListTab']/div[@class='trans-container']/p[@class='additional']),

    # C2E
    web_trans_title => q(//div[@id='tWebTrans']/h3/span/a[@rel='#tWebTrans']),
    web_trans       => q(//div[@id='tWebTrans']/div/div/span[@style='cursor: pointer;']),
    web_phase       => q(//div[@id='tWebTrans']/div[@id='webPhrase']/p),

    # Phase
    phase_list     => [ 'wordGroup', 'synonyms', 'relWordTab' ],
    phase_title    => q(//div[@id='eTransform']/h3/span/a[@rel='#REPLACEME']/span),
    phase_contents => q(//div[@id='transformToggle']/div[@id='REPLACEME']),
    phase_suffix   => [ '/p',        '/ul/*',    '/p' ],

    # Examples
    example_list     => [ 'bilingual', 'originalSound', 'authority' ],
    example_title    => q(//div[@id='examples']/h3/span/a[@rel='#REPLACEME']/span),
    example_contents => q(//div[@id='examples']/div/div[@id='REPLACEME']/ul),
);

my $keyword = $ARGV[0];
$keyword = uri_escape ($keyword);
$url =~ s/KEYW0RD/$keyword/;
die "You must pass a Chinese/English word as parameter" if (!$keyword);

my $ua = LWP::UserAgent->new;
$ua->timeout (30);
$ua->env_proxy;
my $page = $ua->get ($url);
die "Cannot connect to $url" unless ($page->is_success);

my $buffer;
my $screen = IO::Scalar->new (\$buffer);
my $tree = HTML::TreeBuilder::XPath->new_from_content ($page->decoded_content);

get_translation ($tree, $screen);
print $buffer;

END {
    $tree->delete ();
}

sub get_translation {
    my ($tree, $screen) = @_;
    my $indent = 2;
    if (!$tree->exists ($ele_map{results_contents})) {
        $screen->print ("Something really goes wrong\n");
        return 1;
    }
    # No translation found
    elsif (!$tree->exists ($ele_map{word})) {
        $screen->print ($tree->findvalue ($ele_map{results_contents}));
        return 0;
    }
    # Get the spell and phonetic of the word
    else {
        $screen->print ($tree->findvalue ($ele_map{word}), "\n");
        $screen->print ("\n");
    }

    # Get the basic translation of the word
    if ($tree->exists ($ele_map{basic_trans})) {
        $screen->print ("基本释意\n");
        my @translation_list = ();
        if ($tree->exists ($ele_map{basic_trans} . '/li')) {
            @translation_list = $tree->findvalues ($ele_map{basic_trans} . '/li');
        }
        elsif ($tree->exists ($ele_map{basic_trans} . '/p')) {
            @translation_list = $tree->findvalues ($ele_map{basic_trans} . '/p');
        }
        push @translation_list, $tree->findvalue ($ele_map{addt_trans}) if ($tree->exists ($ele_map{addt_trans}));
        map { $screen->print (' ' x $indent, trim ($_), "\n") } (@translation_list);
        $screen->print ("\n");
    }

    # Get web translation of chinese word
    if ($tree->exists ($ele_map{web_trans_title})) {
        $screen->print ($tree->findvalue ($ele_map{web_trans_title}), "\n");
        map { $screen->print (' ' x $indent, trim ($_), "\n") } ($tree->findvalues ($ele_map{web_trans}));
        $screen->print ("\n");
    }
    if ($tree->exists ($ele_map{web_phase})) {
        $screen->print ("短语\n");
        map { $screen->print (' ' x $indent, trim ($_), "\n") } ($tree->findvalues ($ele_map{web_phase}));
        $screen->print ("\n");
    }

    # Get the phase of the word
    for my $index (0 .. $#{ $ele_map{phase_list} }) {
        my $phase         = $ele_map{phase_list}->[$index];
        my $title_path    = $ele_map{phase_title};
        my $contents_path = $ele_map{phase_contents};
        my $suffix        = $ele_map{phase_suffix}->[$index];
        $title_path    =~ s/REPLACEME/$phase/;
        $contents_path =~ s/REPLACEME/$phase/;
        if ($tree->exists ($title_path)) {
            $screen->print ($tree->findvalue ($title_path), "\n");
            if ($tree->exists ($contents_path . $suffix)) {
                my @phase_list = $tree->findvalues ($contents_path . $suffix);
                map { $screen->print (' ' x $indent, trim ($_), "\n") } (@phase_list);
            } else {
                # TODO
            }
        }
    }
    $screen->print ("\n");

    # Get the examples of the word
    for my $index (0 .. $#{ $ele_map{example_list} }) {
        my $example       = $ele_map{example_list}->[$index];
        my $title_path    = $ele_map{example_title};
        my $contents_path = $ele_map{example_contents};
        $title_path    =~ s/REPLACEME/$example/;
        $contents_path =~ s/REPLACEME/$example/;
        if ($tree->exists ($title_path)) {
            $screen->print ($tree->findvalue ($title_path), "\n");
            if ($tree->exists ($contents_path)) {
                my @example_list = $tree->findvalues ($contents_path . '/li/p[not(@class)]');
                while (my ($is_a_trans, $value) = each @example_list) {
                    $screen->print (' ' x $indent, ($is_a_trans & 1) && ($index < 2) ? "~ $value" : $value, "\n");
                }
            }
            $screen->print ("\n");
        }
    }
}

sub trim {
    my $string = shift;
    $string =~ s/^\s*(.*?)\s*$/$1/;
    return $string;
}

