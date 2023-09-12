package Trog::Vars;

use strict;
use warnings;

#1MB chunks
our $CHUNK_SEP  = 'tCMSep666YOLO42069';
our $CHUNK_SIZE = 1024000;

our %content_types = (
    plain => "text/plain;",
    html  => "text/html; charset=UTF-8",
    json  => "application/json;",
    blob  => "application/octet-stream;",
);

our %cache_control = (
    revalidate => "no-cache, max-age=0",
    nocache    => "no-store",
    static     => "public, max-age=604800, immutable",
);
