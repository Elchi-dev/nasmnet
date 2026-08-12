%ifndef NASMNET_SYS_INC
%define NASMNET_SYS_INC

%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_CLOSE       3
%define SYS_SOCKET      41
%define SYS_ACCEPT      43
%define SYS_BIND        49
%define SYS_LISTEN      50
%define SYS_SETSOCKOPT  54
%define SYS_EXIT_GROUP  231

%define AF_INET         2
%define SOCK_STREAM     1
%define SOL_SOCKET      1
%define SO_REUSEADDR    2

%define STDOUT          1
%define STDERR          2

%define BACKLOG         128
%define BUFSIZE         4096

%define EINTR           4
%define ECONNABORTED    103

struc sockaddr_in
    .sin_family  resw 1
    .sin_port    resw 1
    .sin_addr    resd 1
    .sin_zero    resb 8
endstruc

%endif
