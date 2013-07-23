#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Time::HiRes qw( usleep );
use IO::Handle;
use List::Util qw( first );
use Text::ParseWords;
use threads;
use threads::shared;
use Thread::Queue;



our $VERSION = '1.08';

my %options;
interpretCommandline(\%options);

my $gnuplotVersion = getGnuplotVersion();

# list containing the plot data. Each element is a reference to a list, representing the data for
# one curve. The first 'point' is a hash describing various curve parameters. The rest are all
# references to lists of (x,y) tuples
my @curves = ();

# list mapping curve names to their indices in the @curves list
my %curveIndices = ();

# now start the data acquisition and plotting threads
my $dataQueue;
my $xwindow;

my $streamingFinished : shared = undef;
if($options{stream})
{
  if( $options{hardcopy})
  {
    $options{stream} = undef;
  }

  $dataQueue  = Thread::Queue->new();
  my $addThr  = threads->create(\&mainThread);
  my $plotThr = threads->create(\&plotThread);

  while(<>)
  {
    chomp;

    # place every line of input to the queue, so that the plotting thread can process it. if we are
    # using an implicit domain (x = line number), then we send it on the data queue also, since
    # $. is not meaningful in the plotting thread
    if(!$options{domain})
    {
      $_ .= " $.";
    }
    $dataQueue->enqueue($_);
  }

  $streamingFinished = 1;

  $plotThr->join();
  $addThr->join();
}
else
{ mainThread(); }



sub interpretCommandline
{
  my $usage = <<OEF;
Usage: $0 [options] file1 file2 ...
  any number of data files can be given on the cmdline. They will be processed
  in sequence. If no data files are given, data will be read in from standard
  input.

  --[no]domain         If enabled, the first element of each line is the
                       domain variable.  If not, the point index is used

  --[no]dataid         If enabled, each data point is preceded by the ID
                       of the data set that point corresponds to. This ID is
                       interpreted as a string, NOT as just a number. If not
                       enabled, the order of the point is used.

As an example, if line 3 of the input is "0 9 1 20"
 '--nodomain --nodataid' would parse the 4 numbers as points in 4
   different curves at x=3

 '--domain --nodataid' would parse the 4 numbers as points in 3 different
   curves at x=0. Here, 0 is the x-variable and 9,1,20 are the data values

 '--nodomain --dataid' would parse the 4 numbers as points in 2 different
   curves at x=3. Here 0 and 1 are the data IDs and 9 and 20 are the
   data values

 '--domain --dataid' would parse the 4 numbers as a single point at
   x=0. Here 9 is the data ID and 1 is the data value. 20 is an extra
   value, so it is ignored. If another value followed 20, we'd get another
   point in curve ID 20

  --[no]3d             Do [not] plot in 3D. This only makes sense with --domain.
                       Each domain here is an (x,y) tuple

  --colormap           Show a colormapped xy plot. Requires extra data for the color.
                       zmin/zmax can be used to set the extents of the colors.
                       Automatically increments extraValuesPerPoint

  --[no]stream         Do [not] display the data a point at a time, as it
                       comes in

  --[no]lines          Do [not] draw lines to connect consecutive points
  --[no]points         Do [not] draw points
  --circles            Plot with circles. This requires a radius be specified for
                       each point. Automatically increments extraValuesPerPoint

  --xlabel xxx         Set x-axis label
  --ylabel xxx         Set y-axis label
  --y2label xxx        Set y2-axis label. Does not apply to 3d plots
  --zlabel xxx         Set y-axis label. Only applies to 3d plots

  --title  xxx         Set the title of the plot

  --legend xxx         Set the label for a curve plot. Give this option multiple
                       times for multiple curves

  --autolegend         Use the curve IDs for the legend

  --xlen xxx           When using --stream, sets the size of the x-window to plot.
                       Omit this or set it to 0 to plot ALL the data. Does not
                       make sense with 3d plots. Implies --monotonic

  --xmin  xxx          Set the range for the x axis. These are ignored in a
                       streaming plot
  --xmax  xxx          Set the range for the x axis. These are ignored in a
                       streaming plot
  --ymin  xxx          Set the range for the y axis.
  --ymax  xxx          Set the range for the y axis.
  --y2min xxx          Set the range for the y2 axis. Does not apply to 3d plots.
  --y2max xxx          Set the range for the y2 axis. Does not apply to 3d plots.
  --zmin  xxx          Set the range for the z axis. Only applies to 3d plots or colormaps.
  --zmax  xxx          Set the range for the z axis. Only applies to 3d plots or colormaps.

  --y2    xxx          Plot the data specified by this curve ID on the y2 axis.
                       Without --dataid, the ID is just an ordered 0-based index.
                       Does not apply to 3d plots.

  --curvestyle xxx     Additional style per curve. Give this option multiple
                       times for multiple curves

  --curvestyleall xxx  Additional styles for ALL curves.

  --extracmds xxx      Additional commands. These could contain extra global styles
                       for instance

  --size  xxx          Gnuplot size option

  --square             Plot data with aspect ratio 1

  --hardcopy xxx       If not streaming, output to a file specified here. Format
                       inferred from filename

  --maxcurves xxx      The maximum allowed number of curves. This is 100 by default,
                       but can be reset with this option. This exists purely to
                       prevent perl from allocating all of the system's memory when
                       reading bogus data

  --monotonic          If --domain is given, checks to make sure that the x-
                       coordinate in the input data is monotonically increasing.
                       If a given x-variable is in the past, all data currently
                       cached for this curve is purged. Without --monotonic, all
                       data is kept. Does not make sense with 3d plots.
                       No --monotonic by default.

  --extraValuesPerPoint xxx
                       How many extra values are given for each data point. Normally this
                       is 0, and does not need to be specified, but sometimes we want
                       extra data, like for colors or point sizes or error bars, etc.
                       feedGnuplot options that require this (colormap, circles)
                       automatically set it. This option is ONLY needed if unknown styles are
                       used, with --curvestyleall for instance

  --dump               Instead of printing to gnuplot, print to STDOUT. For
                       debugging.
OEF

  # if I'm using a self-plotting data file with a #! line, then $ARGV[0] will contain ALL of the
  # options and $ARGV[1] will contain the data file to plot. In this case I need to split $ARGV[0] so
  # that GetOptions() can parse it correctly. On the other hand, if I'm plotting normally (not with
  # #!)  a file with spaces in the filename, I don't want to split the filename. Hopefully this logic
  # takes care of both those cases.
  if (exists $ARGV[0] && !-r $ARGV[0])
  {
    unshift @ARGV, shellwords shift @ARGV;
  }

  my $options = shift;

  # everything off by default:
  # do not stream in the data by default
  # point plotting by default.
  # no monotonicity checks by default
  $options{ maxcurves } = 100;

  GetOptions($options, 'stream!', 'domain!', 'dataid!', '3d!', 'colormap!', 'lines!', 'points!',
             'circles', 'legend=s@', 'autolegend!', 'xlabel=s', 'ylabel=s', 'y2label=s', 'zlabel=s',
             'title=s', 'xlen=f', 'ymin=f', 'ymax=f', 'xmin=f', 'xmax=f', 'y2min=f', 'y2max=f',
             'zmin=f', 'zmax=f', 'y2=s@', 'curvestyle=s@', 'curvestyleall=s', 'extracmds=s@',
             'size=s', 'square!', 'hardcopy=s', 'maxcurves=i', 'monotonic!',
             'extraValuesPerPoint=i', 'help', 'dump') or die($usage);

  # handle various cmdline-option errors
  if ( $options->{help} )
  {
    print STDERR "$usage\n";
    exit 0;
  }

  $options->{curvestyleall} = '' unless defined $options->{curvestyleall};

  if ($options->{colormap})
  {
    # colormap styles all curves with palette. Seems like there should be a way to do this with a
    # global setting, but I can't get that to work
    $options->{curvestyleall} .= ' palette';
  }

  if ( $options->{'3d'} )
  {
    if ( !$options->{domain} )
    {
      print STDERR "--3d only makes sense with --domain\n";
      exit -1;
    }

    if ( defined $options->{y2min} || defined $options->{y2max} || defined $options->{y2} )
    {
      print STDERR "--3d does not make sense with --y2...\n";
      exit -1;
    }

    if ( defined $options->{xlen} )
    {
      print STDERR "--3d does not make sense with --xlen\n";
      exit -1;
    }

    if ( defined $options->{monotonic} )
    {
      print STDERR "--3d does not make sense with --monotonic\n";
      exit -1;
    }
  }
  elsif (!$options->{colormap})
  {
    if ( defined $options->{zmin} || defined $options->{zmax} || defined $options->{zlabel} )
    {
      print STDERR "--zmin/zmax/zlabel only makes sense with --3d or --colormap\n";
      exit -1;
    }
  }

  if(defined $options{xlen} && !defined $options{stream} )
  {
    print STDERR "--xlen does not make sense without --stream\n";
    exit -1;
  }

  # --xlen implies an order to the data, so I force monotonicity
  $options{monotonic} = defined $options{xlen};
}

sub getGnuplotVersion
{
  open(GNUPLOT_VERSION, 'gnuplot --version |') or die "Couldn't run gnuplot";
  my ($gnuplotVersion) = <GNUPLOT_VERSION> =~ /gnuplot\s*(\d*\.\d*)/;
  if (!$gnuplotVersion)
  {
    print STDERR "Couldn't find the version of gnuplot. Does it work? Trying anyway...\n";
    $gnuplotVersion = 0;
  }
  close(GNUPLOT_VERSION);

  return $gnuplotVersion;
}

sub plotThread
{
  while(! $streamingFinished)
  {
    sleep(1);
    $dataQueue->enqueue('Plot now');
  }

  $dataQueue->enqueue(undef);

}

sub mainThread
{
    my $valuesPerPoint = 1;
    if($options{extraValuesPerPoint}) { $valuesPerPoint += $options{extraValuesPerPoint}; }
    if($options{colormap})            { $valuesPerPoint++; }
    if($options{circles} )            { $valuesPerPoint++; }

    local *PIPE;
    my $dopersist = '';

    if($gnuplotVersion >= 4.3)
    {
      $dopersist = '--persist' if(!$options{stream});
    }

    if(exists $options{dump})
    {
      *PIPE = *STDOUT;
    }
    else
    {
      open PIPE, "|gnuplot $dopersist" or die "Can't initialize gnuplot\n";
    }
    autoflush PIPE 1;

    my $outputfile;
    my $outputfileType;
    if( $options{hardcopy})
    {
      $outputfile = $options{hardcopy};
      ($outputfileType) = $outputfile =~ /\.(eps|ps|pdf|png)$/;
      if(!$outputfileType) { die("Only .eps, .ps, .pdf and .png supported\n"); }

      my %terminalOpts =
      ( eps  => 'postscript solid color enhanced eps',
        ps   => 'postscript solid color landscape 10',
        pdf  => 'pdfcairo solid color font ",10" size 11in,8.5in',
        png  => 'png size 1280,1024' );

      print PIPE "set terminal $terminalOpts{$outputfileType}\n";
      print PIPE "set output \"$outputfile\"\n";
    }
    else
    {
      print PIPE "set terminal x11\n";
    }

    # If a bound isn't given I want to set it to the empty string, so I can communicate it simply to
    # gnuplot
    $options{xmin}  = '' unless defined $options{xmin};
    $options{xmax}  = '' unless defined $options{xmax};
    $options{ymin}  = '' unless defined $options{ymin};
    $options{ymax}  = '' unless defined $options{ymax};
    $options{y2min} = '' unless defined $options{y2min};
    $options{y2max} = '' unless defined $options{y2max};
    $options{zmin}  = '' unless defined $options{zmin};
    $options{zmax}  = '' unless defined $options{zmax};

    print PIPE "set xtics\n";
    if($options{y2})
    {
      print PIPE "set ytics nomirror\n";
      print PIPE "set y2tics\n";
      # if any of the ranges are given, set the range
      print PIPE "set y2range [". $options{y2min} . ":" . $options{y2max} ."]\n" if length( $options{y2min} . $options{y2max} );
    }

    # set up plotting style
    my $style = '';
    if($options{lines})  { $style .= 'lines';}
    if($options{points}) { $style .= 'points';}
    if($options{circles})
    {
      $options{curvestyleall} = "with circles $options{curvestyleall}";
    }

    # if any of the ranges are given, set the range
    print PIPE "set xrange [". $options{xmin} . ":" . $options{xmax} ."]\n" if length( $options{xmin} . $options{xmax} );
    print PIPE "set yrange [". $options{ymin} . ":" . $options{ymax} ."]\n" if length( $options{ymin} . $options{ymax} );
    print PIPE "set zrange [". $options{zmin} . ":" . $options{zmax} ."]\n" if length( $options{zmin} . $options{zmax} );
    print PIPE "set style data $style\n" if $style;
    print PIPE "set grid\n";

    print(PIPE "set xlabel  \"" . $options{xlabel } . "\"\n") if defined $options{xlabel};
    print(PIPE "set ylabel  \"" . $options{ylabel } . "\"\n") if defined $options{ylabel};
    print(PIPE "set zlabel  \"" . $options{zlabel } . "\"\n") if defined $options{zlabel};
    print(PIPE "set y2label \"" . $options{y2label} . "\"\n") if defined $options{y2label};
    print(PIPE "set title   \"" . $options{title  } . "\"\n") if defined $options{title};

    if($options{square})
    {
      $options{size} = '' unless defined $options{size};
      $options{size} .= ' ratio -1';
    }
    print(PIPE "set size $options{size}\n")                     if defined $options{size};

    if($options{colormap})
    {
      print PIPE "set cbrange [". $options{zmin} . ":" . $options{zmax} ."]\n" if length( $options{zmin} . $options{zmax} );
    }

# For the specified values, set the legend entries to 'title "blah blah"'
    if($options{legend})
    {
      my $id = 0;
      foreach (@{$options{legend}})
      {
        setCurveLabel($id++, $_);
      }
    }

# add the extra curve options
    if($options{curvestyle})
    {
      my $id = 0;
      foreach (@{$options{curvestyle}})
      {
        addCurveOption($id++, $_);
      }
    }

# For the values requested to be printed on the y2 axis, set that
    foreach (@{$options{y2}})
    {
      addCurveOption($_, 'axes x1y2 linewidth 3');
    }

# add the extra global options
    if($options{extracmds})
    {
      foreach (@{$options{extracmds}})
      {
        print(PIPE "$_\n");
      }
    }

    # regexp for a possibly floating point, possibly scientific notation number
    my $numRE   = '-?\d*\.?\d+(?:[Ee][-+]?\d+)?';

    # a point may be preceded by an id
    my $pointRE = $options{dataid} ? '(\w+)\s+' : '()';
    $pointRE .= '(' . join('\s+', ($numRE) x $valuesPerPoint) . ')';
    $pointRE = qr/$pointRE/;

    my @domain;
    my $haveNewData;

    # I should be using the // operator, but I'd like to be compatible with perl 5.8
    while( $_ = (defined $dataQueue ? $dataQueue->dequeue() : <>))
    {
      next if /^#/o;

      if($_ ne 'Plot now')
      {
        # parse the incoming data lines. The format is
        # x id0 dat0 id1 dat1 ....
        # where idX is the ID of the curve that datX corresponds to
        #
        # $options{domain} indicates whether the initial 'x' is given or not (if not, the line
        # number is used)
        # $options{dataid} indicates whether idX is given or not (if not, the point order in the
        # line is used)
        # 3d plots require $options{domain}, and dictate "x y" for the domain instead of just "x"

        if($options{domain})
        {
          /($numRE)/go or next;
          $domain[0] = $1;
          if($options{'3d'})
          {
            /($numRE)/go or next;
            $domain[1] = $1;
          }
        }
        else
        {
          # since $. is not meaningful in the plotting thread if we're using the data queue, we pass
          # $. on the data queue in that case
          if(defined $dataQueue)
          {
            s/ ([\d]+)$//o;
            $domain[0] = $1;
          }
          else
          {
            $domain[0] = $.;
          }
        }

        my $id = -1;
        while (/$pointRE/go)
        {
          if($1 ne '') {$id = $1;}
          else         {$id++;   }

          $haveNewData = 1;
          pushPoint(getCurve($id),
                    [@domain, split( /\s+/, $2)]);
        }
      }

      elsif($options{stream})
      {
        # only redraw a streaming plot if there's new data to plot
        next unless $haveNewData;
        $haveNewData = undef;

        if( $options{xlen} )
        {
          pruneOldData($domain[0] - $options{xlen});
          plotStoredData($domain[0] - $options{xlen}, $domain[0]);
        }
        else
        { plotStoredData(); }
      }
    }

    # finished reading in all of the data
    if($options{stream})
    {
      print PIPE "exit;\n";
      close PIPE;
    }
    else
    {
      plotStoredData();

      if( $options{hardcopy})
      {
        print PIPE "set output\n";
        # sleep until the plot file exists, and it is closed. Sometimes the output is
        # still being written at this point
        usleep(100_000) until -e $outputfile;
        usleep(100_000) until(system("fuser -s \"$outputfile\""));

        print "Wrote output to $outputfile\n";
        return;
      }

      # we persist gnuplot, so we shouldn't need this sleep. However, once
      # gnuplot exits, but the persistent window sticks around, you can no
      # longer interactively zoom the plot. So we still sleep
      sleep(100000);
    }
}

sub pruneOldData
{
  my ($oldestx) = @_;

  foreach my $xy (@curves)
  {
    if( @$xy > 1 )
    {
      if( my $firstInWindow = first {$xy->[$_][0] >= $oldestx} 1..$#$xy )
      { splice( @$xy, 1, $firstInWindow-1 ); }
      else
      { splice( @$xy, 1); }
    }
  }
}

sub plotStoredData
{
  my ($xmin, $xmax) = @_;
  print PIPE "set xrange [$xmin:$xmax]\n" if defined $xmin;

  # get the options for those curves that have any data
  my @nonemptyCurves = grep {@$_ > 1} @curves;
  my @extraopts = map {$_->[0]{options}} @nonemptyCurves;

  my $body = join(', ' , map({ '"-"' . $_} @extraopts) );
  if($options{'3d'}) { print PIPE "splot $body\n"; }
  else               { print PIPE  "plot $body\n"; }

  foreach my $buf (@nonemptyCurves)
  {
    # send each point to gnuplot. Ignore the first "point" since it's the
    # curve options
    for my $elem (@{$buf}[1..$#$buf])
    {
      print PIPE "@$elem\n";
    }
    print PIPE "e\n";
  }
}

sub updateCurveOptions
{
  # generates the 'options' string for a curve, based on its legend title and its other options
  # These could be integrated into a single string, but that raises an issue in the no-title
  # case. When no title is specified, gnuplot will still add a legend entry with an unhelpful '-'
  # label. Thus I explicitly do 'notitle' for that case

  my ($curveoptions, $id) = @_;

  my $title;
  $title = $curveoptions->{title} if(defined $curveoptions->{title});
  $title = $id                    if $options{autolegend};

  my $titleoption = defined $title ? "title \"$title\"" : "notitle";
  my $extraoption = defined $options{curvestyleall} ? $options{curvestyleall} : '';
  $curveoptions->{options} = "$titleoption $curveoptions->{extraoptions} $extraoption";
}

sub getCurve
{
  # This function returns the curve corresponding to a particular label, creating a new curve if
  # necessary

  if(scalar @curves >= $options{maxcurves})
  {
    print STDERR "Tried to exceed the --maxcurves setting.\n";
    print STDERR "Invoke with a higher --maxcurves limit if you really want to do this.\n";
    exit;
  }

  my ($id) = @_;

  if( !exists $curveIndices{$id} )
  {
    push @curves, [{extraoptions => ' '}]; # push a curve with no data and no options
    $curveIndices{$id} =  $#curves;

    updateCurveOptions($curves[$#curves][0], $id);
  }
  return $curves[$curveIndices{$id}];
}

sub addCurveOption
{
  my ($id, $str) = @_;

  my $curve = getCurve($id);
  $curve->[0]{extraoptions} .= "$str ";
  updateCurveOptions($curve->[0], $id);
}

sub setCurveLabel
{
  my ($id, $str) = @_;

  my $curve = getCurve($id);
  $curve->[0]{title} = $str;
  updateCurveOptions($curve->[0], $id);
}

# function to add a point to the plot. Assumes that the curve indexed by $idx already exists
sub pushPoint
{
  my ($curve, $xy) = @_;

  if($options{monotonic})
  {
    if( @$curve > 1 && $xy->[0] < $curve->[$#{$curve}][0] )
    {
      # the x-coordinate of the new point is in the past, so I wipe out all the data for this curve
      # and start anew
      splice( @$curve, 1, @$curve-1 );
    }
  }

  push @$curve, $xy;
}

__END__

=head1 NAME

feedGnuplot - A pipe-oriented frontend to Gnuplot

=head1 SYNOPSIS

Simple plotting of stored data:

 $ seq 5 | awk '{print 2*$1, $1*$1}'
 2 1
 4 4
 6 9
 8 16
 10 25

 $ seq 5 | awk '{print 2*$1, $1*$1}' |
   feedGnuplot --lines --points --legend "data 0" --title "Test plot" --y2 1

Simple real-time plotting example: plot how much data is received on the wlan0
network interface in bytes/second (uses bash, awk and Linux):

 $ while true; do sleep 1; cat /proc/net/dev; done |
   awk '/wlan0/ {if(b) {print $2-b; fflush()} b=$2}' |
   feedGnuplot --lines --stream --xlen 10 --ylabel 'Bytes/sec' --xlabel seconds

=head1 DESCRIPTION

This is a flexible, command-line-oriented frontend to Gnuplot. It creates
plots from data coming in on STDIN or given in a filename passed on the
commandline. Various data representations are supported, as is hardcopy
output and streaming display of live data. A simple example:

 $ seq 5 | awk '{print 2*$1, $1*$1}' | feedGnuplot

You should see a plot with two curves. The C<awk> command generates some data to
plot and the C<feedGnuplot> reads it in from STDIN and generates the plot. The
<awk> invocation is just an example; more interesting things would be plotted in
normal usage. None of the commandline-options are required for the most basic
plotting. Input parsing is flexible; every line need not have the same number of
points. New curves will be created as needed.

The most commonly used functionality of gnuplot is supported directly by the
script. Anything not directly supported can still be done with the
C<--extracmds> and C<--curvestyle> options. Arbitrary gnuplot commands can be
passed in with C<--extracmds>. For example, to turn off the grid, pass in
C<--extracmds 'unset grid'>. As many of these options as needed can be pased
in. To add arbitrary curve styles, use C<--curvestyle extrastyle>. Pass these
more than once to affect more than one curve. To apply an extra style to I<all>
the curves, pass in C<--curvestyleall extrastyle>.

=head2 Data formats

By default, each value present in the incoming data represents a distinct data
point, as demonstrated in the above example (we had 10 numbers in the input and
10 points in the plot). If requested, the script supports more sophisticated
interpretation of input data

=head3 Domain selection

If C<--domain> is passed in, the first value on each line of input is
interpreted as the I<X>-value for the rest of the data on that line. Without
C<--domain> the I<X>-value is the line number, and the first value on a line is
a plain data point like the others. Default is C<--nodomain>. Thus the example
above produces 2 curves, with B<1,2,3,4,5> as the I<X>-values. If we run the
same command with --domain:

 $ seq 5 | awk '{print 2*$1, $1*$1}' | feedGnuplot --domain

we get only 1 curve, with B<2,4,6,8,10> as the I<X>-values. As many points as
desired can appear on a single line, but all points on a line are associated
with the I<X>-value at the start of that line.

=head3 Curve indexing

By default, each column represents a separate curve. This is fine unless sparse
data is to be plotted. With the C<--dataid> option, each point is represented by
2 values: a string identifying the curve, and the value itself. If we add
C<--dataid> to the original example:

 $ seq 5 | awk '{print 2*$1, $1*$1}' | feedGnuplot --dataid --autolegend

we get 5 different curves with one point in each. The first column, as produced
by C<awk>, is B<2,4,6,8,10>. These are interpreted as the IDs of the curves to
be plotted. The C<--autolegend> option adds a legend using the given IDs to
label the curves. The IDs need not be numbers; generic strings are accepted. As
many points as desired can appear on a single line. C<--domain> can be used in
conjunction with C<--dataid>.

=head3 Multi-value style support

Depending on how gnuplot is plotting the data, more than one value may be needed
to represent a single point. For example, the script has support to plot all the
data with C<--circles>. This requires a radius to be specified for each point in
addition to the position of the point. Thus, when plotting with C<--circles>, 2
numbers are read for each data point instead of 1. A similar situation exists
with C<--colormap> where each point contains the position I<and> the
color. There are other gnuplot styles that require more data (such as error
bars), but none of these are directly supported by the script. They can still be
used, though, by specifying the specific style with C<--curvestyle>, and
specifying how many extra values are needed for each point with
C<--extraValuesPerPoint extra>. C<--extraValuesPerPoint> is ONLY needed for the
styles not explicitly supported; supported styles set that variable
automatically.

=head3 3D data

To plot 3D data, pass in C<--3d>. C<--domain> MUST be given when plotting 3D
data to avoid domain ambiguity. If 3D data is being plotted, there are by
definition 2 domain values instead of one (I<Z> as a function of I<X> and I<Y>
instead of I<Y> as a function of I<X>). Thus the first 2 values on each line are
interpreted as the domain instead of just 1. The rest of the processing happens
the same way as before.

=head2 Real-time streaming data

To plot real-time data, pass in the C<--stream> option. Data will then be
plotted as it is received, with the refresh rate limited to 1Hz (currently
hard-coded). To plot only the most recent data (instead of I<all> the data),
C<--xlen windowsize> can be given. This will create an constantly-updating,
scrolling view of the recent past. C<windowsize> should be replaced by the
desired length of the domain window to plot, in domain units (passed-in values
if C<--domain> or line numbers otherwise).

=head2 Hardcopy output

The script is able to produce hardcopy output with C<--hardcopy outputfile>. The
output type is inferred from the filename with B<.ps>, B<.eps>, B<.pdf> and
B<.png> currently supported.

=head2 Self-plotting data files

This script can be used to enable self-plotting data files. There are 2 ways of
doing this: with a shebang (#!) or with inline perl data.

=head3 Self-plotting data with a #!

A self-plotting, executable data file C<data> is formatted as

 $ cat data
 #!/usr/bin/feedGnuplot --lines --points
 2 1
 4 4
 6 9
 8 16
 10 25
 12 36
 14 49
 16 64
 18 81
 20 100
 22 121
 24 144
 26 169
 28 196
 30 225

This is the shebang (#!) line followed by the data, formatted as before. The
data file can be plotted simply with

 $ ./data

The caveats here are that on Linux the whole #! line is limited to 127 charaters
and that the full path to feedGnuplot must be given. The 127 character limit is
a serious limitation, but this can likely be resolved with a kernel patch. I
have only tried on Linux 2.6.

=head3 Self-plotting data with perl inline data

Perl supports storing data and code in the same file. This can also be used to
create self-plotting files:

 $ cat plotdata.pl
 #!/usr/bin/perl
 use strict;
 use warnings;

 open PLOT, "| feedGnuplot --lines --points" or die "Couldn't open plotting pipe";
 while( <DATA> )
 {
   my @xy = split;
   print PLOT "@xy\n";
 }
 __DATA__
 2 1
 4 4
 6 9
 8 16
 10 25
 12 36
 14 49
 16 64
 18 81
 20 100
 22 121
 24 144
 26 169
 28 196
 30 225

This is especially useful if the logged data is not in a format directly
supported by feedGnuplot. Raw data can be stored after the __DATA__ directive,
with a small perl script to manipulate the data into a useable format and send
it to the plotter.

=head2 Further help

All the options are described with

 $ feedGnuplot --help

=head1 ACKNOWLEDGEMENT

This program is originally based on the driveGnuPlots.pl script from
Thanassis Tsiodras. It is available from his site at
L<http://users.softlab.ece.ntua.gr/~ttsiod/gnuplotStreaming.html>

=head1 REPOSITORY

L<https://github.com/dkogan/feedgnuplot>

=head1 AUTHOR

Dima Kogan, C<< <dkogan at cds.caltech.edu> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Dima Kogan.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
