#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <glib.h>
#include <glib-object.h>
#include <searpc.h>
#include <paquet.hpp>
#include <boost/process.hpp>


namespace bp = boost::process;


#define BUFLEN 256

static char *transport_callback(void *arg, const char *fcall_str,
                                size_t fcall_len, size_t *ret_len){ 
    int fd, ret;
    char buf[BUFLEN];
    packet *pac, *pac_ret;
   
    fd = (int)(long) arg;
    pac = (packet *)buf;

    /* construct the packet */
    pac->length = htons((uint16_t)fcall_len);
    memcpy(pac->data, fcall_str, fcall_len);

    /* send the packet */
    if ( writen (fd, buf, PACKET_HEADER_LENGTH + fcall_len) == -1) {
        fprintf (stderr, "write failed: %s\n", strerror(errno));
        exit(-1);
    }
    
    /* read the returned packet */
    pac_ret = read_packet(fd, buf);
    if (pac_ret == NULL) {
      fprintf(stderr, "read packet failed: %s\n", strerror(errno));
        exit(-1);
    }
    
    *ret_len = ntohs(pac_ret->length);

    return g_strndup(pac_ret->data, *ret_len);
}

int connection_init(int *sockfd, struct sockaddr_in *servaddr){
    int ret;
    ret = *sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (ret < 0) {
        fprintf(stderr, "socket failed: %s\n", strerror(errno));
        return -1;
    }
    int on = 1;
    if (setsockopt (*sockfd, SOL_SOCKET, SO_REUSEADDR, (char*)&on, sizeof(on)) < 0) {
        fprintf (stderr, "setsockopt of SO_REUSEADDR error: %s\n", strerror(errno));
        return -1;
    }

    ret = connect(*sockfd, (struct sockaddr *)servaddr, sizeof(*servaddr));
    if (ret < 0) {
        fprintf(stderr, "connect failed: %s\n", strerror(errno));
        return -1;
    }

    return 0;
}


int main(){
   struct hostent *h;

 
    if ((h=gethostbyname("https://storage.staging.dev.tipi.build")) == NULL) {
      herror("gethostbyname");
      exit(1);
    }

    printf("Host name  : %s\n", h->h_name);
    printf("IP adresse : %s\n",inet_ntoa(*((struct in_addr *)h->h_addr)));


  SearpcClient *rpc_client = nullptr;
  int result = 999;
  GError *error = NULL;
  int sockfd;
  char *ret_str;
  struct sockaddr_in servaddr;
  std::string repo_id = "92c64e22";

  #if !GLIB_CHECK_VERSION(2, 36, 0)
    g_type_init();
#endif

   memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_port = htons(49153);
    //servaddr.sin_port = htons(53951);

    inet_pton(AF_INET, "127.0.0.1", &servaddr.sin_addr);

    if (connection_init(&sockfd, &servaddr)<0) exit(-1);

    std::cout<<"connection passer"<<std::endl;


  rpc_client = searpc_client_new();
  rpc_client->send = transport_callback;
  rpc_client->arg = (void *)(long)sockfd;

  /*
  the repo id and the name of the lib are not the same 
  In repo.db in the table repo we can found the repo_id 
liub name : 92c64e22
repo_id = 4134b2c9-0aae-4e80-a01d-5eec3d0b4659
*/

    std::cout<<"appelle de la fct"<<std::endl;

  result = searpc_client_call__int ( rpc_client, "seafile_destroy_repo", &error,
                                    1, "string", "4134b2c9-0aae-4e80-a01d-5eec3d0b4659");
  if( error != NULL ) {
    std::cout<<"error in delete repo"<<std::endl;
    std::cout << error->message << std::endl;
    g_clear_error (&error);
}
    std::cout<<"post appelle de la fct"<<std::endl;


  std::cout<<result<<std::endl;
  return 0;
}