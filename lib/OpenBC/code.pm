package OpenBC::code;
#use Moose;
#use Redis;
#use YAML;
use Dancer::Logger;
use OpenBC::wiki;
use LWP::Simple qw($ua get);
use Template;

#has 'db' => (is => 'ro', lazy_build => 1);

sub importCode {
    my $self = shift;
    my $title = shift;
    my $url = shift;
    my $tt = Template->new || die "Error creating tt";
    my $linenum=0;
    my @doc;
    my $toc ="test";
    my @chapter;

#    $url="https://ia700301.us.archive.org/35/items/gov.ga.building/ga_building_djvu.txt";
    $url = "http://openbuildingcodes.com/code.txt";

    my $htmlcontent = get $url;

    my @content = split /\n/, $htmlcontent;

    foreach my $line (@content) {
        my $chapterNum = 0;
        $linenum++;
        my $currentChapter="";

        # Codes with deviations will often begin a line with [F]. For now,
        # remove this
        if ($line =~ /^\[F\]/) { $line = substr($line, 4); }

        #If the line starts with "Chapter __" - it's probably a chapter
        if ($line =~ /^CHAPTER ([0-9])/) {
            $currentChapter=$content[$linenum+1];
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

#    push @doc, {level=>"level",name=>"name",codeid=>2,contents=>"cofjdksjf"};
    foreach my $section (@doc) {
        my $chapterNum=0;
        my $vars = {
            level => $section->{level},
            name => $section->{name},
            codeid => $section->{codeid},
            contents => $section->{contents}
        };

        if ($vars->{codeid} =~ m/^\d*$/) {
            $chapterNum = $vars->{codeid};
        }

        $tt->process('views/importTOC.tt', $vars, \$toc) || die $tt->error;
        $tt->process('views/importCode.tt', $vars, \$chapter[$chapterNum]);
        Dancer::Logger::debug($chapterNum."woop->".$chapter[$chapterNum]);
    }

    my $wiki = OpenBC::wiki->new;
    $wiki->write($title.":toc", $toc);
    for (my $i = 0; $i<$#chapter; $i++) {
        my $ch = $i+1;
        $wiki->write($title.":ch".$ch, $chapter[$i]);
        $wiki->addChapter($title, $ch);
    }
}

#sub _build_db { }

1;
