package OpenBC::Controller;

use Dancer;
 
get '/' => sub {
          return 'Hello World!';
      };

sub run {
      start;
}
