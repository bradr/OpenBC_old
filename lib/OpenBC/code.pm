package OpenBC::code;
use Moose;
use Redis;
use YAML;
use LWP::Simple qw($ua getprint);

has 'db' => (is => 'ro', lazy_build => 1);

sub import {
    my $self = shift;
    my $title = shift;
    my $url = shift;
    my $tt = Template->new();
    my $linenum=0;
    my @doc;
    my $toc;
    my @chapter;

    my $content="1\n2\n3\n4\n5\n6";

    $content = getprint $url;

    my @content = split /\n/, $content;

    foreach my $line (@content) {
        my $chapterNum = 0;
        $linenum++;
        my $currentChapter;

        # Codes with deviations will often begin a line with [F]. For now,
        # remove this
        if ($line =~ /^\[F\]/) { $line = substr($line, 4); }

        #If the line starts with "Chapter __" - it's probably a chapter
        if ($line =~ /^CHAPTER ([0-9])/) {
            <$content>;
            $currentChapter=<$content>;
            my $currentChapterNum=$1;
            push @doc, { level => "0", name => $line." ".$currentChapter, codeid=>$1 };
        }
        #Add Sections
        elsif ($line =~ /^((?:[0-9]+\.)+)([0-9]+) ([^\.]+). (.+)/) {
            my $sectionNum=$1.$2;
            my $level=1;
            while ($sectionNum =~ /\./g) { $level++; }
            my $sectionName=$sectionNum." ".$3.". ";
            my $contents=$4;
            chomp $contents;
            push @doc, { level=>$level, name=>$sectionName, codeid=>$sectionNum, contents=>$contents };
        }        
        #The rest is all content. Add it to the last "section"
        else {
            if($#doc>0 && $line !~ /INTERNATIONAL BUILDING CODE/ && $line !~ /^[0-9]+ *\n/ && $line !~ /^$currentChapter/) {
                if ($line !~ /^\n/ || $line !~ /^ *\n/) {
                    $doc[-1]{contents} = $doc[-1]{contents} . $line;
                }
            }
        }
    }

    foreach my $section (@doc) {
        my $chapterNum=0;
        my $vars = {
            level => $section->{level},
            name => $section->{name},
            codeid => $section->{codeid},
            contents => $section->{contents}
        };
        my $codeid = $section->{codeid};

        if ($codeid =~ m/^\d*$/) {
            $chapterNum = $codeid;
        }

        template('importTOC.tt', $vars, \$toc);
        template('importCode.tt', $vars, \$chapter[$chapterNum]);
    }

#    $toc="tocmothaeffa";

    my $wiki = OpenBC::wiki->new;
    my $toctitle = $title.":toc";
    $wiki->write($toctitle, $toc);
    for (my $i = 0; $i<$#chapter; $i++) {
        my $ch = $i+1;
        $wiki->write($title.":ch".$ch, $chapter[$ch]);
        $wiki->addChapter($title, $ch);
    }
}

1;
