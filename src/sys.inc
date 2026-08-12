%ifndef NASMNET_SYS_INC
%define NASMNET_SYS_INC

%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_CLOSE       3
%define SYS_RT_SIGACTION 13
%define SYS_RT_SIGRETURN 15
%define SYS_RT_SIGPROCMASK 14
%define SYS_FCNTL       72
%define SYS_PPOLL       271
%define SYS_EPOLL_CREATE1 291
%define SYS_EPOLL_CTL   233
%define SYS_EPOLL_PWAIT 281
%define SYS_ACCEPT4     288
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

%define SIG_IGN         1
%define SA_RESTORER     0x04000000
%define SIGINT          2
%define SIGPIPE         13
%define SIGTERM         15
%define SIG_BLOCK       0
%define SIG_UNBLOCK     1

; Bit n-1 stands for signal n, so SIGINT and SIGTERM together.
%define STOPMASK        0x4002

%define F_SETFL         4
%define O_NONBLOCK      0x800
%define POLLIN          1

%define EPOLL_CTL_ADD   1
%define EPOLL_CTL_DEL   2
%define EPOLL_CTL_MOD   3
%define EPOLLIN         0x001
%define EPOLLOUT        0x004
%define EPOLLERR        0x008
%define EPOLLHUP        0x010
%define EPOLLRDHUP      0x2000
%define MAX_EVENTS      64
%define SOCK_NONBLOCK   0x800

; The kernel packs this structure on x86_64, so data sits at offset 4
; and is not aligned.
%define EV_SIZE         12
%define LISTEN_TAG      0xFFFFFFFFFFFFFFFF

%define STDOUT          1
%define STDERR          2

%define BACKLOG         128
%define BUFSIZE         4096
%define MAX_CONNS       1024

%define CONN_READING    0
%define CONN_WRITING    1

%define EINTR           4
%define EAGAIN          11
%define ECONNABORTED    103

struc conn
    .fd     resd 1
    .state  resd 1
    .off    resq 1
    .len    resq 1
    .buf    resb BUFSIZE
endstruc

struc sockaddr_in
    .sin_family  resw 1
    .sin_port    resw 1
    .sin_addr    resd 1
    .sin_zero    resb 8
endstruc

%endif
