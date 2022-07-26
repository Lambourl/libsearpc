#pragma once
#include <stdint.h>
#include <stdio.h>
#include <errno.h>
#include <iostream>

#ifdef WIN32
    #include <windows.h>
    #include <inttypes.h>
    #include <winsock2.h>
    #include <ctype.h>
    #include <ws2tcpip.h>
    #define UNUSED 
#else
    #include <unistd.h>
    #include <sys/types.h>
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <netdb.h> 
    #include <arpa/inet.h>
#endif

typedef struct packet {
    uint16_t length;
    char data[0];
} packet;

# define PACKET_HEADER_LENGTH sizeof(packet)

static ssize_t						/* Write "n" bytes to a descriptor. */
writen(int fd, const void *vptr, size_t n){
	size_t		nleft;
	ssize_t		nwritten;
	const char	*ptr = (const char *) vptr;
std::cout<<"j ecris "<<std::endl;
	nleft = n;
	while (nleft > 0) {
#ifdef WIN32
        if ( (nwritten = send(fd, ptr, nleft,0)) <= 0) {
#else
		if ( (nwritten = write(fd, ptr, nleft)) <= 0) {
#endif
			if (nwritten < 0 && errno == EINTR){
				nwritten = 0;	
                write(fd, ptr, nleft);
                }	/* and call write() again */
			else
				return(-1);			/* error */
		}

		nleft -= nwritten;
		ptr   += nwritten;
	}
	return(n);
}

static ssize_t						/* Read "n" bytes from a descriptor. */
readn(int fd, char *buf, size_t n)
{
	size_t	nleft;
	ssize_t	nread;
    std::cout<<"je lis  "<<std::endl;


	nleft = n;
	while (nleft > 0) {
#ifdef WIN32
        if ( (nread = recv(fd, buf, nleft, 0)) < 0) {
#else
		if ( (nread = read(fd, buf, nleft)) < 0) {
#endif          
			if (errno == EINTR){
				nread = 0;
                //nread = read(fd, buf, nleft);
                	}	/* and call read() again */
			else
				return(-1);
		} else if (nread == 0)
			break;				/* EOF */

		nleft -= nread;
        buf += nread;
	}

	return(n - nleft);		/* return >= 0 */    
}


/* read a packet into a buffer, and return the pacet pointer */
packet *
read_packet(int sockfd, char *buf)
{
    packet *pac;
    int len;
    /* read the length part */
    if (readn (sockfd, buf, PACKET_HEADER_LENGTH) != PACKET_HEADER_LENGTH) {
        fprintf(stderr, "read header error: %s\n", strerror(errno));
        exit(-1);
    }
    pac = (packet *)buf;
    len = ntohs(pac->length);
    /* read the data */
    if (len <= 0)
        return NULL;
    else if (readn (sockfd, buf + PACKET_HEADER_LENGTH, len) != len)
        return NULL;

    return pac;
}
