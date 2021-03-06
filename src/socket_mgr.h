#ifndef _SOCKET_MGR_H_
#define _SOCKET_MGR_H_

#include "hive_socket.h"

struct socket_mgr_state;


struct socket_mgr_state* socket_mgr_create();
void socket_mgr_release(struct socket_mgr_state* state);
void socket_mgr_exit(struct socket_mgr_state* state);

int socket_mgr_connect(struct socket_mgr_state* state, const char* host, uint16_t port, char const** out_err, uint32_t actor_handle);
int socket_mgr_listen(struct socket_mgr_state* state, const char* host, uint16_t port, uint32_t actor_handle);
int socket_mgr_send(struct socket_mgr_state* state, int id, const void* data, size_t size);
int socket_mgr_close(struct socket_mgr_state* state, int id);
int socket_mgr_attach(struct socket_mgr_state* state, int id, uint32_t actor_handle);
int socket_mgr_addrinfo(struct socket_mgr_state* state, int id, struct socket_addrinfo* out_addrinfo, const char** out_error);

int socket_mgr_update(struct socket_mgr_state* state);


#endif