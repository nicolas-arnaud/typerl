#!/usr/bin/perl
# Version: 1.0
# Description: A program to test typing speed and accuracy
#

use strict;
use warnings;

use Term::ReadKey;
use Term::ReadLine;

use Time::HiRes qw( time );
use FindBin qw($RealBin);

use lib "$RealBin/lib";

use wordlists;
use layouts;
use menu;

my $layout_name = "none";
my $wordlist_file = "new";

my @words;
my $layout;

main();

sub main {
    print "\e[2J\e[H"; # Clear screen and move cursor to top-left corner
    print "# TYPERL\n\n";
    print " Start test\n";
    print " Select layout ($layout_name)\n";
    print " Select words list ($wordlist_file)\n";
    print " Create words list\n";
    print " Exit\n";

    print "\e[3;0H>";
    my $key = menu::menu(0, 4);
    if ($key eq 0) {
        $layout = layouts::get($layout_name);
        @words = wordlists::get($wordlist_file);
        start();
    } elsif ($key eq 1) {
        $layout_name = layouts::choose();
        main();
    } elsif ($key eq 2) {
        $wordlist_file = wordlists::choose();
        main();
    } elsif ($key eq 3) {
        $wordlist_file = wordlists::random_creation();
        main();
    } elsif ($key eq 4 or $key eq "q" or $key eq "\e") {
        exit;
    }
}

sub start {
    my %char_times;
    my %incorrect_chars;
    my $start_time = 0;
    my $char_time = 0;
    my $prev_time = $start_time;
    my $total_time = 0;
    my $total_chars = 0;
    my $correct_chars = 0;
    my $fixed_chars = 0;

    print "\e[2J\e[H";
    if ($layout_name ne "none") {
        print "\e[90m$layout\e[0m\n";
    }

    print "*" x 80 . "\n";
    print "*              Press 'esc' anytime to exit and 'tab' to restart.               *\n";
    print "*" x 80 . "\n";    

    my @lines;
    my $n = 0;



    for (my $i = 0; $i < scalar(@words); $i++) {
        if ($i % 10 eq 9 or $i eq scalar(@words) - 1) {
            $lines[$n] .= $words[$i];
            $n++;
        } else {
            $lines[$n] .= $words[$i] . " ";
            if (length($lines[$n]) + length($words[$i]) > 80) {
                $lines[$n] =~ s/ $//;
                $n++;
            }
        }
    }

    print "\e[s"; # Save cursor position
    foreach my $line (@lines) {
        print "$line\n";
    }
    print "\e[u"; # Restore cursor position

    my $char_input = '';
    my $prev_char = '';

    for (my $n = 0; $n < scalar(@lines); $n++) {
        my $line = $lines[$n];
        my $char = '';

        for (my $i = 0; $i <= length($line); $i++) {
            $char = substr($line, $i, 1);
            if ($layout_name ne "none") {
                layouts::update($layout, $char, $prev_char);
            }

            $char_input = readChar();

            if ($start_time eq 0) {
                $start_time = time;
                $prev_time = $start_time;
            }

            if ($char_input eq "\e") {
                main();
            } elsif ($char_input eq "\t") {
                start();
            } elsif ($char_input eq "^H" or $char_input eq "\x7f") {
                $fixed_chars++;
                if ($i eq 0) {
                    $n--;
                    $line = $lines[$n];
                    $i = length($line);
                    print "\e[1A\e[" . $i . "C";
                    $i--;
                } else {
                    $i--;
                    print "\e[D";
                    print substr($line, $i, 1);
                    print "\e[D";
                    redo;
                }
            } elsif ($char_input eq "\n") {
                if ($i eq length($line)) {
                    print " \e[1E\e[1G";
                    if ($fixed_chars gt 0) {
                        $fixed_chars--;
                    }
                    next;
                }
                redo;
            } elsif ($i eq length($line)) {
                print "\e[31m█\e[0m\e[1E\e[1G";
                next;
            }

            if (not exists $incorrect_chars{$char}) {
                $incorrect_chars{$char} = 0;
            }

            if ($char eq $char_input) {
                if (exists $char_times{$char}) {
                    push @{$char_times{$char}}, $char_time;
                } else {
                    $char_times{$char} = [$char_time];
                }
                if ($fixed_chars eq 0) {
                    print "\e[92m$char\e[0m";
                } else {
                    print "\e[93m$char\e[0m";
                    $fixed_chars--;
                }
                $correct_chars++;
            } else {
                if ($fixed_chars gt 0) {
                    $fixed_chars--;
                }
                $incorrect_chars{$char}++;
                print "\e[91m$char_input\e[0m";
            }

            $total_chars++;
            $char_time = time - $prev_time;
            $prev_time = time;
            $prev_char = $char;
        }
    }
    
    my $cpm = 60 * ($total_chars / (time - $start_time));

    print  "\n" . "-" x 80 . "\n";
    printf "Time: %.2f seconds\n", time - $start_time;
    printf "Speed: %.2f CPM\n", $cpm;
    printf "Speed: %.2f WPM\n", 60 * (scalar(@words) / (time - $start_time));
    print  "-" x 80 . "\n";
    printf "Errors: %s\n", $total_chars - $correct_chars;
    printf "Accuracy: %.2f%%\n", 100 * ($correct_chars / $total_chars);
    print  "-" x 80 . "\n";
    $n = 0;
    foreach my $char (sort keys %char_times) {
        my $char_avg_time = sprintf("%.2f", average(@{$char_times{$char}}));
        my $char_accuracy = sprintf("%.2f", 100 * (1 - ($incorrect_chars{$char} /
            (scalar(@{$char_times{$char}}) + $incorrect_chars{$char}))));

        my $char_cpm = 0;
        if ($char_avg_time ne '0.00') {
            $char_cpm = 60 / $char_avg_time;
        }
        if ($char_accuracy eq '100.00') {
            if ($char_cpm gt $cpm) {
                print "\e[92m";
            } else {
                print "\e[93m";
            }
        } else {
            print "\e[91m";
        }

        printf "%s: %d CPM (%s%%)", $char, $char_cpm, $char_accuracy;
        print "\e[0m";

        if ($n % 3 == 0) {
            print "\n";
        } else {
            print "\t";
        }
        $n++;
    }
    print  "\n" . "-" x 80 . "\n";

    print "Press 'tab' to restart or 'esc' to return to main menu.\n";
    while (1) {
        my $key = readChar();

        if ($key eq "\t") {
            start();
        } elsif ($key eq "\e") {
            main();
        }
        last;
    }
}


# Function to calculate the average of a list of numbers
sub average {
    my $total = 0;
    foreach my $number (@_) {
        $total += $number;
    }
    return $total / scalar(@_);
}

# Function
sub readChar {
    ReadMode('cbreak');
    my $key = Term::ReadKey::ReadKey(0);
    ReadMode(0);
    return $key;
}
